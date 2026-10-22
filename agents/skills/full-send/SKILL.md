---
name: full-send
description: Use when told to "full send" a code change in a project.
---

## Overview

Your job is to take what's been discussed and see it all the way through to a ready-to-merge PR. Implement the change, validate it, and get a finalized PR up.

## Process

### Write the code

First implement the change/proposal agreen upon. Follow all agreed upon principles and best practices, and align with existing codebase patterns and design.

Iterate, test, and refine the code until you're happy with it. Make sure not to introduce regressions. Make sure to validate your work as you build - test the code, take and review screenshots and recordings if applicable, etc.

Guiding principles:

- simplicity
- succinct tests. keep them narrow and focused
- prefer new primitives over "hacks"

All in all, this can be summed up as "as much code as necessary, but no more".

### Finalizing the code

Call the skill for "audit-for-simplicity", "use-claude", and "use-codex" if they're available in this environment:

Depending on the complexity of the change, do an appropriate combination of:

- Subagent reviews. Use as many Luna/Haiku-tier subagents as you want. Use 6.1 Sol/Opus 5.5-tier subagents for heavier work. Never use Astra/Fable tier subagents without explicity permission.
- Other-agent reviews. Use Claude or Codex (whichever you are not, or both if you are neither) to review your changes. Bounce back and forth with them until you both agree on the change. You have final say, if you ultimately cannot agree, but inform the user of this.
- Audits for simplicity. Do as many rounds as you think you should - a good baseline is continuing until no more valid improvements come up.

If this project has CI, make sure CI is green. 

### Finishing up

Get these changes pushed up, create a PR for this, and babysit it until it's ready.

Call the skill tool for "github-pr-issue" and "github-babysit-pr" if they're available in this environment:
