---
name: subagents
description: Use whenever spawning subagents.
---

1. Find the models the harness can run (in OpenCode, the `models` tool).
2. Choose by purpose:
   - Cheap or bulk work: Luna/Haiku tier.
   - Heavier work and reviews: GPT 6.2 Sol or Claude Opus 5.5.
   - Heaviest work (use sparingly): GPT 6.2 Astra/Claude Fable 5.2
   - Other-model review: the family you are not.
3. Spawn a native subagent with that model. Always prefer the current harness; explicitly set the subagent model if necessary.
4. Fallback only if the model isn't available natively:
   - GPT: Use the "use-codex" skill
   - Claude: Use the "use-claude" skill
