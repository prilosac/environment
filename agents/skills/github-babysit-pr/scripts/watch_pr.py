#!/usr/bin/env python3
"""Read-only current-head review/CI watcher; completion is not merge readiness."""

import argparse
import json
import math
import re
import subprocess
import time


class Deadline(Exception):
    pass


def api(endpoint, deadline, paginated=False):
    remaining = deadline - time.monotonic()
    if remaining <= 0:
        raise Deadline
    command = ["gh", "api", endpoint]
    if paginated:
        command += ["--paginate", "--slurp"]
    try:
        result = subprocess.run(
            command, capture_output=True, text=True, timeout=min(30, remaining)
        )
    except subprocess.TimeoutExpired as error:
        if time.monotonic() >= deadline:
            raise Deadline from error
        raise RuntimeError("GitHub request exceeded 30 seconds") from error
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or "gh api failed")
    return json.loads(result.stdout)


def pages(endpoint, deadline, key=None):
    return [
        item
        for page in api(endpoint + "?per_page=100", deadline, paginated=True)
        for item in (page[key] if key else page)
    ]


def snapshot(repo, number, reviewer, ci, deadline):
    root = f"repos/{repo}"
    pull = f"{root}/pulls/{number}"
    pr = api(pull, deadline)
    head = pr["head"]["sha"]
    reviews = [
        {"id": r["id"], "state": r["state"], "url": r["html_url"]}
        for r in pages(f"{pull}/reviews", deadline)
        if r["user"]["login"].casefold() == reviewer.casefold()
        and r.get("commit_id") == head
        and r.get("submitted_at")
        and r["state"] in {"APPROVED", "CHANGES_REQUESTED", "COMMENTED"}
    ]
    checks = []
    if ci:
        for c in pages(f"{root}/commits/{head}/check-runs", deadline, "check_runs"):
            checks.append({
                "name": c["name"], "state": c["status"],
                "conclusion": c["conclusion"], "url": c["html_url"],
            })
        # Status history is newest first; only the latest state of each context counts.
        statuses = {}
        for s in pages(f"{root}/commits/{head}/statuses", deadline):
            statuses.setdefault(s["context"], {
                "name": s["context"], "state": s["state"], "url": s["target_url"],
            })
        checks.extend(statuses.values())
    latest = api(pull, deadline)
    if latest["head"]["sha"] != head:
        return None  # Discard data collected across a push; poll the new head.
    return {
        "head": head, "pr_state": latest["state"], "reviews": reviews,
        "checks": sorted(checks, key=lambda c: (c["name"], c["url"] or "")),
    }


def finished(data, ci):
    return bool(data["reviews"]) and (
        not ci or bool(data["checks"]) and all(
            c["state"] in {"completed", "success", "failure", "error"}
            for c in data["checks"]
        )
    )


def emit(event, **data):
    print(json.dumps({"event": event, **data}), flush=True)


def watch(repo, number, reviewer, ci=False, interval=60, timeout=1800):
    deadline = time.monotonic() + timeout
    previous = None
    try:
        while time.monotonic() < deadline:
            data = snapshot(repo, number, reviewer, ci, deadline)
            if time.monotonic() >= deadline:
                raise Deadline
            if data is not None:
                if data != previous:
                    emit("snapshot", **data)
                    previous = data
                if data["pr_state"] != "open":
                    emit("closed", head=data["head"])
                    return 0
                if finished(data, ci):
                    emit("observed", head=data["head"])
                    return 0
            time.sleep(min(interval, max(0, deadline - time.monotonic())))
    except Deadline:
        pass
    except (OSError, RuntimeError, ValueError, KeyError, TypeError) as error:
        emit("error", message=str(error))
        return 2
    emit("timeout")
    return 1


def positive(value):
    value = float(value)
    if not math.isfinite(value) or value <= 0:
        raise argparse.ArgumentTypeError("must be finite and positive")
    return value


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("repo", help="OWNER/REPO")
    parser.add_argument("number", type=int, help="pull request number")
    parser.add_argument("--reviewer", required=True, help="review author's GitHub login")
    parser.add_argument("--ci", action="store_true", help="also wait for visible CI to finish")
    parser.add_argument("--interval", type=positive, default=60, help="poll seconds (default: 60)")
    parser.add_argument("--timeout", type=positive, default=1800, help="total seconds (default: 1800)")
    args = parser.parse_args()
    if not re.fullmatch(r"[\w.-]+/[\w.-]+", args.repo) or args.number <= 0:
        parser.error("expected OWNER/REPO and a positive PR number")
    return watch(**vars(args))


if __name__ == "__main__":
    raise SystemExit(main())
