---
name: github-pr-issue
description: Use when asked to create or interact with a GitHub PR or Issue
---

Prefer using the `gh` cli for all GitHub actions including but not limited to creating, editing, or commenting on issues and PRs. Use the `gh` CLI --attach flag where available when attaching images to issues and PRs. Older versions of the GitHub CLI don't support --attach; fallback to putting images in `.github/screenshots/` within the repo, and link to them.

Use the "humanizer" skill to improve your prose if it's available in this environment.

## PR

When asked to create a PR, always do so on the current branch unless otherwise specified. Stop and ask the user how to proceed if you find yourself needing to take any destructive actions.

Always create PRs as drafts until they are finalized or asked otherwise - CI only runs on PRs marked ready for review by a human, so this saves us CI minutes.

PR descriptions should be written for a human to be able to quickly review, understand the scope of the change and it's impact, and allow them to easily verify changes. To this end, include Mermaid diagrams, screenshots, short videos, or whatever artefacts are applicable for this change. The PR needs to contain irrefutable proof to convince the reviewer that the changes achieve the desired means and give them confidence it was done in a reasonable way.

## Validation

When asked for a link to test, spin up a dev server and hand the link over to the user. If the system you're on is using Tailscale, provide a Tailscale link.

## Assignment

Always assign the PR to @prilosac when it's ready to be reviewed.
