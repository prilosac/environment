---
name: release-notes
description: Release note content structure and guidelines for GitHub Releases.
---

## What I do
Generate concise release notes based on the differences between those tags in git for GitHub releases. My final output should consist ONLY of the final release notes, ready to publish to GitHub

Use git diff to compare the latest release tag to the one before it. Release tags start with "v" and look like `v0.1.5`.

`git diff v0.1.4 v0.1.5`

Use other git commands as necessary to investigate the code and gather context.

## Release Notes Structure

## Summary

<1-3 sentence overview of the changes made.>

## Key Changes

- <Highlight 1>
- <Highlight 2>
- <Highlight 3>

## Changes

If one of the following sections has no entries, omit it entirely.

### Added
- <Entry describing added feature>

### Changed
- <Entry describing changed feature>

### Removed
- <Entry describing removed feature>

## Writing Style
- Use active voice
- Focus on user-facing impact
- Keep total length under 200 words
- No emojis
- No technical jargon unless necessary
