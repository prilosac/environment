---
name: github-pr-issue
description: Use when asked to create or interact with a GitHub PR or Issue
---

Prefer using the `gh` cli for all GitHub actions including but not limited to creating, editing, or commenting on issues and PRs. Use the `gh` CLI --attach flag where available when attaching images to issues and PRs. Older versions of the GitHub CLI don't support --attach; fallback to putting images in `.github/screenshots/` within the repo, and link to them.

## PR

When asked to create a PR, always start by making sure you're up to date on main and create a new branch to make the changes in. If the working environment is dirty (uncommitted files, unstaged edits, etc.), stop and ask the user how to proceed first.

Always create draft PRs by default unless asked otherwise - CI only runs on PRs marked ready for review by a human, so this saves us CI minutes.

PR descriptions should be written for a human to be able to quickly review, understand the scope of the change and it's impact, and allow them to easily verify changes by including Mermaid diagrams, screenshots, or short videos where applicable.

