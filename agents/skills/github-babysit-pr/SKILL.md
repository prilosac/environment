---
name: github-babysit-pr
description: Use when asked to babysit, watch, monitor, or otherwise see a PR through to being completely ready to merge
---

Babysitting a PR means watching and iterating on it until it is ready to merge. Specifically, that means:

- Watching for Code Review comments on GitHub
- Iteratively dealing with them by either responding with changes or ignoring them, using your best judgement
- If asked to ensure CI goes green, mark the PR as ready for review and verify CI passes (draft PRs often do not run CI)

Use the bundled watcher, not a new polling script (Python 3 and existing `gh` authentication):

```sh
python3 <skill-dir>/scripts/watch_pr.py OWNER/REPO PR
```

It waits for the next PR/review/comment/CI change: exit 0 on change or closure, 1 on timeout, 2 on error. Inspect, act, and repeat until ready; a change is not approval. Do not merge unless asked.

If Python 3 is unavailable, use `gh pr checks PR --repo OWNER/REPO --watch` directly and continue checking reviews/comments with `gh`.
