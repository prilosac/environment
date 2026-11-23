---
name: use-claude
description: Use as a fallback when needing to consult with Claude if your harness doesn't natively support Claude subagents.
---

Do not use this skill if the current harness has native Claude subagent capability or `claude` is not set up on this computer.

Otherwise, talk to Claude using `claude --model <model> -p "<prompt>" <other-args>`

Default to Claude Opus 5.5 unless otherwise specified.
