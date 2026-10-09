import contextlib
import importlib.util
import io
import json
from pathlib import Path
import subprocess
import unittest
from unittest.mock import patch


spec = importlib.util.spec_from_file_location(
    "watch_pr", Path(__file__).parents[1] / "scripts" / "watch_pr.py"
)
watcher = importlib.util.module_from_spec(spec)
spec.loader.exec_module(watcher)


def review(**overrides):
    return {
        "id": 1, "user": {"login": "reviewer"}, "commit_id": "new",
        "submitted_at": "2026-10-09T12:00:00Z", "state": "COMMENTED",
        "html_url": "https://github.com/review/1", **overrides,
    }


def data(reviews=None, checks=None, head="new", pr_state="open"):
    return {
        "head": head, "pr_state": pr_state,
        "reviews": [review()] if reviews is None else reviews,
        "checks": [] if checks is None else checks,
    }


class WatchTests(unittest.TestCase):
    def test_reviews_must_be_submitted_by_target_on_current_head(self):
        invalid = [
            review(state="PENDING", submitted_at=None),
            review(state="PENDING"), review(commit_id="old"),
            review(user={"login": "someone-else"}), review(state="DISMISSED"),
        ]
        pr = {"head": {"sha": "new"}, "state": "open"}
        with patch.object(watcher, "api", return_value=pr), patch.object(
            watcher, "pages", return_value=invalid + [review()]
        ):
            result = watcher.snapshot("owner/repo", 1, "REVIEWER", False, 999)
        self.assertEqual([r["id"] for r in result["reviews"]], [1])

    def test_push_during_fetch_discards_snapshot(self):
        with patch.object(watcher, "api", side_effect=[
            {"head": {"sha": "old"}}, {"head": {"sha": "new"}},
        ]), patch.object(watcher, "pages", return_value=[review(commit_id="old")]):
            self.assertIsNone(watcher.snapshot("owner/repo", 1, "reviewer", False, 999))

    def test_pagination_flattens_arrays_and_check_run_objects(self):
        for key, response in [
            (None, [[review(commit_id="old")], [review()]]),
            ("check_runs", [{"check_runs": [1]}, {"check_runs": [2]}]),
        ]:
            with self.subTest(key=key), patch.object(watcher, "api", return_value=response) as api:
                self.assertEqual(len(watcher.pages("endpoint", 999, key)), 2)
                api.assert_called_once_with("endpoint?per_page=100", 999, paginated=True)

    def test_ci_uses_latest_status_per_context(self):
        pr = {"head": {"sha": "new"}, "state": "open"}
        with patch.object(watcher, "api", return_value=pr), patch.object(
            watcher, "pages", side_effect=[
                [review()], [{
                    "name": "lint", "status": "completed", "conclusion": "skipped",
                    "html_url": "https://github.com/check/1",
                }], [
                    {"context": "build", "state": "success", "target_url": None},
                    {"context": "build", "state": "pending", "target_url": None},
                ],
            ]
        ):
            result = watcher.snapshot("owner/repo", 1, "reviewer", True, 999)
        self.assertEqual(result["checks"], [
            {"name": "build", "state": "success", "url": None},
            {"name": "lint", "state": "completed", "conclusion": "skipped",
             "url": "https://github.com/check/1"},
        ])
        self.assertTrue(watcher.finished(result, True))

    def test_missing_pending_and_finished_ci_are_distinct(self):
        self.assertFalse(watcher.finished(data(reviews=[]), False))
        self.assertTrue(watcher.finished(data(), False))
        self.assertFalse(watcher.finished(data(), True))
        for state in ["queued", "in_progress", "pending", "waiting"]:
            self.assertFalse(watcher.finished(data(checks=[{"state": state}]), True))
        for conclusion in ["success", "failure", "skipped", "neutral", "cancelled"]:
            # Finished is deliberately not a claim of success or readiness.
            self.assertTrue(watcher.finished(data(checks=[{
                "state": "completed", "conclusion": conclusion,
            }]), True))

    def run_watch(self, snapshots, ci=False, timeout=180):
        clock = [0]
        def sleep(seconds):
            clock[0] += seconds
        output = io.StringIO()
        with patch.object(watcher.time, "monotonic", side_effect=lambda: clock[0]), \
             patch.object(watcher.time, "sleep", side_effect=sleep), \
             patch.object(watcher, "snapshot", side_effect=snapshots) as fetch, \
             contextlib.redirect_stdout(output):
            code = watcher.watch("owner/repo", 1, "reviewer", ci, timeout=timeout)
        return code, [json.loads(line) for line in output.getvalue().splitlines()], fetch.call_count

    def test_head_changes_and_unchanged_snapshots(self):
        code, events, calls = self.run_watch([
            data(reviews=[], head="old"), data(reviews=[], head="old"), None, data(),
        ], timeout=240)
        self.assertEqual(code, 0)
        self.assertEqual(calls, 4)
        self.assertEqual([e["event"] for e in events], ["snapshot", "snapshot", "observed"])
        self.assertEqual(events[-1]["head"], "new")

    def test_timeout_is_bounded_even_without_checks(self):
        code, events, calls = self.run_watch([data(), data()], ci=True, timeout=90)
        self.assertEqual((code, calls), (1, 2))
        self.assertEqual([e["event"] for e in events], ["snapshot", "timeout"])

    def test_error_and_closed_are_explicit(self):
        code, events, _ = self.run_watch(RuntimeError("rate limited"))
        self.assertEqual(code, 2)
        self.assertEqual(events, [{"event": "error", "message": "rate limited"}])
        code, events, _ = self.run_watch([data(pr_state="closed")])
        self.assertEqual(code, 0)
        self.assertEqual(events[-1]["event"], "closed")

    def test_requests_are_read_only_and_time_bounded(self):
        response = subprocess.CompletedProcess([], 0, stdout="{}", stderr="")
        with patch.object(watcher.time, "monotonic", return_value=0), \
             patch.object(watcher.subprocess, "run", return_value=response) as run:
            watcher.api("repos/owner/repo/pulls/1", 10)
        self.assertEqual(run.call_args.args[0], ["gh", "api", "repos/owner/repo/pulls/1"])
        self.assertEqual(run.call_args.kwargs["timeout"], 10)

    def test_request_deadline_and_errors(self):
        with patch.object(watcher.time, "monotonic", return_value=10):
            with self.assertRaises(watcher.Deadline):
                watcher.api("endpoint", 10)
        for response in [
            subprocess.CompletedProcess([], 1, stdout="", stderr="not authenticated"),
            subprocess.TimeoutExpired("gh", 30),
        ]:
            with patch.object(watcher.time, "monotonic", return_value=0), \
                 patch.object(watcher.subprocess, "run") as run:
                if isinstance(response, Exception):
                    run.side_effect = response
                else:
                    run.return_value = response
                with self.assertRaises(RuntimeError):
                    watcher.api("endpoint", 60)


if __name__ == "__main__":
    unittest.main()
