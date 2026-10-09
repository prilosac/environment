---
name: github-babysit-pr
description: Use when asked to babysit, watch, monitor, or otherwise see a PR through to being completely ready to merge
---

Inspect the PR's reviews, discussion/inline comments, and CI. Address feedback using your judgement. If asked to ensure CI passes, mark the PR ready for review (drafts often do not run CI) and verify it passes.

Use the bundled watcher, not a new polling script (Python 3 and existing `gh` authentication):

```sh
python3 <skill-dir>/scripts/watch_pr.py OWNER/REPO PR
```

It waits for the next PR/review/comment/CI change: exit 0 on change or closure, 1 on timeout, 2 on error. Inspect, act, and repeat until ready; a change is not approval. Do not merge unless asked.

If Python 3 is unavailable, report the blocker and ask how to proceed; do not install it or write a replacement watcher.
