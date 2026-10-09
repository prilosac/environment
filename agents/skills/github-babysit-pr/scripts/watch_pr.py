#!/usr/bin/env python3
"""Watch a PR for changes using existing gh authentication; never modify it."""

import argparse
import json
import math
import subprocess
import time


def api(endpoint, deadline, paginated=False):
    remaining = deadline - time.monotonic()
    if remaining <= 0:
        raise TimeoutError
    command = ["gh", "api", endpoint]
    if paginated:
        command += ["--paginate", "--slurp"]
    try:
        result = subprocess.run(
            command, capture_output=True, text=True, timeout=min(30, remaining)
        )
    except subprocess.TimeoutExpired as error:
        if time.monotonic() >= deadline:
            raise TimeoutError from error
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


def snapshot(repo, number, deadline):
    root = f"repos/{repo}"
    pull = f"{root}/pulls/{number}"
    pr = api(pull, deadline)
    head = pr["head"]["sha"]
    reviews = pages(f"{pull}/reviews", deadline)
    comments = pages(f"{root}/issues/{number}/comments", deadline)
    review_comments = pages(f"{pull}/comments", deadline)
    checks = pages(f"{root}/commits/{head}/check-runs", deadline, "check_runs")
    statuses = pages(f"{root}/commits/{head}/statuses", deadline)
    latest = api(pull, deadline)
    if latest["head"]["sha"] != head:
        return None  # Discard data collected across a push; poll the new head.
    return {
        "pr": {
            "head": head, "base": latest["base"]["sha"],
            "title": latest["title"], "body": latest["body"],
            "state": latest["state"], "draft": latest["draft"],
            "reviewers": sorted(r["login"] for r in latest["requested_reviewers"]),
            "teams": sorted(t["slug"] for t in latest["requested_teams"]),
        },
        "reviews": reviews, "comments": comments, "review_comments": review_comments,
        "checks": checks, "statuses": statuses,
    }


def emit(event, **data):
    print(json.dumps({"event": event, **data}), flush=True)


def watch(repo, number, interval=60, timeout=1800):
    deadline = time.monotonic() + timeout
    previous = None
    try:
        while time.monotonic() < deadline:
            data = snapshot(repo, number, deadline)
            if time.monotonic() >= deadline:
                raise TimeoutError
            if data is not None:
                if data != previous:
                    # Keep bodies locally for edit detection, not repeated agent output.
                    emit(
                        "snapshot" if previous is None else "changed",
                        head=data["pr"]["head"], state=data["pr"]["state"],
                        areas=[k for k in data if previous is None or data[k] != previous[k]],
                    )
                if data["pr"]["state"] != "open":
                    emit("closed", head=data["pr"]["head"])
                    return 0
                if previous is not None and data != previous:
                    return 0
                previous = data
            time.sleep(min(interval, max(0, deadline - time.monotonic())))
    except TimeoutError:
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
    parser.add_argument("--interval", type=positive, default=60, help="poll seconds (default: 60)")
    parser.add_argument("--timeout", type=positive, default=1800, help="total seconds (default: 1800)")
    args = parser.parse_args()
    if args.repo.count("/") != 1 or args.number <= 0:
        parser.error("expected OWNER/REPO and a positive PR number")
    return watch(**vars(args))


if __name__ == "__main__":
    raise SystemExit(main())
