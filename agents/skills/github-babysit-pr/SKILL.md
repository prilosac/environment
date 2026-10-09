---
name: github-babysit-pr
description: Use when asked to babysit, watch, monitor, or otherwise see a PR through to being completely ready to merge
---

Babysitting a PR means watching and iterating on it until it is ready to merge. Specifically, that means:

- Watching for Code Review comments on GitHub
- Iteratively dealing with them by either responding with changes or ignoring them, using your best judgement
- If asked to ensure CI goes green, mark the PR as ready for review and verify CI passes (draft PRs often do not run CI)

Inspect the PR first, then use the bundled watcher to wait for its next change (Python 3 and existing `gh` authentication):

```sh
python3 <skill-dir>/scripts/watch_pr.py OWNER/REPO PR
```

It watches PR metadata/head, all visible reviews, discussion and inline comments, and CI. It prints compact JSON; exits 0 on change or closure, 1 on timeout, 2 on error. Inspect changes, act as needed, and repeat; an event does not mean ready to merge.

If Python 3 is unavailable, report the blocker and ask how to proceed rather than installing it or writing another watcher. Do not merge unless asked.
