# Team development policy

Shared Team-Sneakymouse / rawb.tv development policy and an agent-assisted development lifecycle (ADLC), independent of a particular agent. Enrolled projects point at a sibling checkout of this repository (see adapters); they do not supersede local instructions until that bootstrap is present.

## Start here

Agents in enrolled projects: read the documents below whose condition matches the change. Do not load the rest.

**Every implementation task**

- [Core policy](policy/core.md): scope, authorization forms, instruction conflicts, and evidence. Reread it whenever authorization or risk is unclear.

**Read when the change…**

- …changes behaviour, or you need to classify its risk or decide on checks and tests: [Scope and testing](policy/scope-and-testing.md) (proportional verification, risk examples, test implementation).
- …is nontrivial or multi-step: [Development workflow](workflows/development.md) (lightweight stages, risk gates, nontrivial evidence shape).
- …touches a Paper plugin at all: [Paper plugin conventions](policy/paper-conventions.md) (threads, reload, public hooks, stable ids, docs).
- …is a substantial Paper feature, adds persistent world state, or spans components or plugins: [Paper plugin maintainability](policy/paper-plugin-maintainability.md) (feature boundaries, lifecycle ownership, cross-plugin contracts, config review).
- …adds or shares Paper util or manager code, or builds a display-only GUI inventory: [SneakyUtils](policy/sneakyutils.md) (when to use and contribute shared utilities; [display-only GUI inventories](policy/sneakyutils.md#display-only-gui-inventories): virtual containers + SneakyItems updater skip).
- …involves custom item looks, resource packs or ItemDisplay: [Paper items / packs / ItemDisplay](policy/paper-items.md) (`item_model` looks, `magicspells:magicitem` place/use identity, server packs without plugin hosting, place defaults).
- …puts models on players (back items, hats over the head slot): [SneakyCosmetics](policy/sneakycosmetics.md) (riding displays; cross-plugin Kotlin API shape).
- …is under review, or started as a pack-only or model-id ask: [Diff scope (review)](review/diff-scope.md) (judgement for asks that grew into APIs or services).

**Optional skills** (load only when relevant; not installed by this repository)

- [Efficiency-review skill](skills/efficiency-review/SKILL.md): Minecraft/Paper and JVM hot-path reviews.
- [SneakySlideDecks authoring skill](skills/sneakyslidedecks-authoring/SKILL.md): illustrated slide decks built locally to a PDF whose art and colours are all Minecraft map colours, for SneakySlideDecks map screens.

**About this repository**

- [Adapter design](adapters/README.md): discovery adapters and sibling-checkout source of truth.
- [Installer design](installer/DESIGN.md): pointer + bootstrap enrollment; `installer/sync-stubs.ps1` or `installer/sync-stubs.sh` rewrites the stubs in enrolled projects (dry run by default).
- [Project context example](examples/project-context.md): local facts, not duplicated team policy.
- [Review scenarios](review/scenarios.md): human/agent behavioral acceptance checks.
- [Approval checklist](review/approval.md): pilot vs general enrollment gates.

## Boundaries

Enrolled plugin repositories carry `.team-policy/pointer.json` and the bootstrap stubs from `adapters/examples/`, written by `installer/sync-stubs.ps1` or `installer/sync-stubs.sh`. Nothing is installed into developer memory or org Hermes profiles. No runtime agent tests or cross-platform installer tests have been performed. No upstream skills are copied; licensing and skill selection remain review items. No license is selected yet: do not assume permission for external redistribution.

**Agent status**

- **Design targets with docs retrieved:** Hermes, Cursor, Codex — adapters drafted; not conformance-verified.
- **Design-scope, validation blocked:** Claude Code, Antigravity — included in design only until fresh-session validation succeeds.
- Developer OSes and supported product versions are not yet specified.

A shared policy governs *when* to use a procedure; optional skills explain *how*. Skills must not introduce unconditional test or approval requirements that contradict the approved policy. Repository files continue to own build commands, architecture constraints, target versions, and explicit local exceptions.
