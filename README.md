# Team development policy

Shared Team-Sneakymouse / rawb.tv development policy and an agent-assisted development lifecycle (ADLC), independent of a particular agent. This repository does not supersede existing project instructions until installed under an approved revision.

## Start here

- [Core policy](policy/core.md): scope, authorization, instruction conflicts, and evidence.
- [Scope and testing](policy/scope-and-testing.md): proportional verification and test implementation.
- [SneakyUtils](policy/sneakyutils.md): use and contribute shared Paper utilities/managers across Team-Sneakymouse plugins.
- [Development workflow](workflows/development.md): lightweight stages and risk gates.
- [Efficiency-review skill](skills/efficiency-review/SKILL.md): optional Minecraft/Paper and JVM hot-path reviews; not installed by this repository.
- [Adapter design](adapters/README.md): Hermes, Cursor, Codex, Claude Code, Antigravity.
- [Installer design](installer/DESIGN.md): explicit, versioned installation; no executable installer yet.
- [Project context example](examples/project-context.md): local facts, not duplicated team policy.
- [Review scenarios](review/scenarios.md): human/agent behavioral acceptance checks.
- [Approval checklist](review/approval.md): decisions required before adoption.

## Boundaries

This contribution is documentation and inert adapter examples only. Nothing is installed into developer memory, Mother Mouse's active profile, or plugin repositories. No runtime agent tests or cross-platform installer tests have been performed. No upstream skills are copied; licensing and skill selection remain review items. No license is selected yet: do not assume permission for external redistribution.

Supported agent targets: Hermes, Cursor, Codex, Claude Code, and Antigravity. Developer OSes and supported product versions are not yet specified. Product adapters remain provisional until verified in fresh sessions on those versions.

A shared policy governs *when* to use a procedure; optional skills explain *how*. Skills must not introduce unconditional test or approval requirements that contradict the approved policy. Repository files continue to own build commands, architecture constraints, target versions, and explicit local exceptions.
