---
name: full-send
description: Use when told to "full send" a code change in a project.
---

# Full Send

When asked to full send, your job is to take what's been discussed and work end-to-end autonomously to see it all the way through to a ready-to-merge change. Implement the change, validate it, and get a finalized change ready.

Only assume full autonomy (and thus, only follow the below instructions) when explicitly asked to "full send" in a clear way.

## Context

Figure out what environment you're in. If remote is a GitHub URL, you're in GitHub. If remote is a different URL and most commits in the history have a Gerrit-style Change-Id, then it's Gerrit. Otherwise it's unknown.

In GitHub environments, call the skill tool for "github-pr-issue" and "github-babysit-pr" if they're available in this environment to carry a PR through to ready. Use them when finishing up the implementation to make a PR and babysit it until it's ready.

In Gerrit environments, we use CRs which are based on a single commit on top of main. --amend a single commit as needed when making changes so that the final ready-to-review commit is one commit on top of main. Do not push anything up in Gerrit environments unless explicitly asked, and when asked, use `git review` to do so.

In unknown environments, don't do anything extra.

## Process

### Implement the change

First implement the proposal agreed upon (if there is one) with the smallest change that works. Follow all agreed upon principles and best practices, and align with existing codebase patterns and design.

Iterate, test, and refine the code until you're happy with it. Make sure not to introduce regressions. Make sure to validate your work as you build - test the code, take and review screenshots and recordings if applicable, etc.

Guiding principles:

- simplicity
- succinct tests. keep them narrow and focused if they exist
- prefer new primitives over "hacks"

All in all, this can be summed up as "as much code as necessary, but no more".

Whenever writing text for a human to read (comments, PR descriptions, etc.), use the "humanize" skill to humanize it.

### Prove it

Get proof for every change made. See "Proof".

### Finalize the code with feedback

Call the skill for "audit-for-simplicity", "use-claude", and "use-codex", and/or harness subagents if they're available in this environment:

Depending on the complexity of the change, do an appropriate combination of:

- Subagent reviews. Use as many Luna/Haiku-tier subagents as you want. Use 6.1 Sol/Opus 5.5-tier subagents for heavier work. Never use Astra/Fable tier subagents without explicit permission.
- Other-agent reviews. Use Claude or Codex (whichever you are not, or both if you are neither) to review your changes. Bounce back and forth with them until you both agree on the change. You have final say, if you ultimately cannot agree, but inform the user of this.
- Audits for simplicity. Do as many rounds as you think you should - a good baseline is continuing until no more valid improvements come up.
- Call the "deslop" skill if it's available and deslop this code

If this project has CI, make sure CI is green. 

### Finishing up

Follow your environment-specific instructions for getting the change ready to merge.

Never merge on your own, instead get it just up to being ready to merge, and hand it back to the user.

## Proof

Proof is evidence you observed yourself in this session: command output, a
reproduction, a screenshot. Use the most direct proof the change allows:

- Reproduce the original failure, apply the fix, then watch the same
  reproduction pass.
- Run the checks that the repo's CI runs (typecheck, lint, tests).
- Add one focused test that fails without the fix, when the behavior has none
  and the repo has a test setup.
- For UI and runtime behavior, run the app and look at the change. Green mocked
  tests do not prove that the user experience works. Attach screenshots to the
  PR when they help and you have a way to upload them.

When you cannot find a way to prove a change, you do not have full confidence.
Ask the user.
