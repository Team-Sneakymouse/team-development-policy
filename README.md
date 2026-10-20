# Team development policy

Shared Team-Sneakymouse / rawb.tv development policy and an agent-assisted development lifecycle (ADLC), independent of a particular agent. Enrolled projects point at a sibling checkout of this repository (see adapters); they do not supersede local instructions until that bootstrap is present.

## Start here

- [Core policy](policy/core.md): scope, authorization forms, instruction conflicts, and evidence.
- [Scope and testing](policy/scope-and-testing.md): proportional verification, risk examples, and test implementation.
- [Paper items / packs / ItemDisplay](policy/paper-items.md): custom looks via `item_model`, server packs without plugin hosting, place defaults.
- [Diff scope (review)](review/diff-scope.md): judgement for pack-only and model-id asks that grew into APIs or services.
- [SneakyUtils](policy/sneakyutils.md): when to use and contribute shared Paper utilities.
- [Development workflow](workflows/development.md): lightweight stages, risk gates, and nontrivial evidence shape.
- [Efficiency-review skill](skills/efficiency-review/SKILL.md): optional Minecraft/Paper and JVM hot-path reviews; load only when relevant; not installed by this repository.
- [Adapter design](adapters/README.md): discovery adapters and sibling-checkout source of truth.
- [Installer design](installer/DESIGN.md): pointer + bootstrap enrollment; no executable installer yet.
- [Project context example](examples/project-context.md): local facts, not duplicated team policy.
- [Review scenarios](review/scenarios.md): human/agent behavioral acceptance checks.
- [Approval checklist](review/approval.md): pilot vs general enrollment gates.

## Boundaries

This contribution is documentation and inert adapter examples only. Nothing is installed into developer memory, org Hermes profiles, or plugin repositories. No runtime agent tests or cross-platform installer tests have been performed. No upstream skills are copied; licensing and skill selection remain review items. No license is selected yet: do not assume permission for external redistribution.

**Agent status**

- **Design targets with docs retrieved:** Hermes, Cursor, Codex — adapters drafted; not conformance-verified.
- **Design-scope, validation blocked:** Claude Code, Antigravity — included in design only until fresh-session validation succeeds.
- Developer OSes and supported product versions are not yet specified.

A shared policy governs *when* to use a procedure; optional skills explain *how*. Skills must not introduce unconditional test or approval requirements that contradict the approved policy. Repository files continue to own build commands, architecture constraints, target versions, and explicit local exceptions.
