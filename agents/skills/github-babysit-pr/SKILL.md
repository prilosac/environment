---
name: github-babysit-pr
description: Use when asked to babysit, watch, monitor, or otherwise see a PR through to being completely ready to merge
---

Babysitting a PR means watching and iterating on it until it is ready to merge. Specifically, that means:

- Watching for Code Review comments on GitHub
- Iteratively dealing with them by either responding with changes or ignoring them, using your best judgement
- If asked to ensure CI goes green, mark the PR as ready for review and verify CI passes (draft PRs often do not run CI)

Use the bundled watcher instead of writing a polling script (requires Python 3 and authenticated `gh`):

```sh
python3 <skill-dir>/scripts/watch_pr.py OWNER/REPO PR --reviewer LOGIN --ci
```

Use the review author's GitHub login; omit `--ci` when not waiting for CI. It prints changed JSON snapshots; exits 0 after a submitted current-head review and optional visible CI finish (or PR closure), 1 on timeout, 2 on error.

Inspect reviews/comments and check results: arrival is not approval, and missing/skipped checks do not prove CI passed. Rerun after fixes and pushes. If a review never schedules, report the blocker instead of guessing request variants. Do not merge unless asked.
