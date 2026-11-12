# Paper plugin maintainability

Use these prompts when a Paper feature is substantial, touches several components, persists world state, or exposes a recurring maintenance problem. They support review and design; they do not prescribe a framework, require a refactor, or set file-size limits. Repository-specific architecture and build rules remain authoritative.

## Feature boundaries

- Keep deterministic rules, calculations, and state transitions testable without a live server when that makes the code simpler. Keep Bukkit/Paper event handling and world effects at the boundary around those rules.
- Keep commands and listeners focused on translating inputs into operations and presenting results. A domain package should describe responsibility, not serve as a reason to put all related behavior in one class.
- For a substantial or cross-cutting feature, identify its main responsibilities (for example: rules, world/entity interaction, persistence, configuration, and presentation) and check that each has a clear owner. Split work into coherent increments where practical.
- A long file, broad diff, or repeated implementation is a review signal, not a defect by itself. Ask whether responsibilities are hard to locate, changes require edits in many unrelated places, or copies are likely to drift. Extract or share code only when that reduces a concrete maintenance cost; avoid speculative frameworks and unrelated cleanup.

## Repeated infrastructure

When multiple features repeat scheduling, event registration, reload, entity discovery, indexing, or cleanup logic, decide deliberately whether to keep it local or share it. Compare the behavior and lifecycle guarantees before abstracting: superficially similar rides may have materially different persistence or cleanup rules. For portable helpers shared by Team-Sneakymouse plugins, follow [SneakyUtils](./sneakyutils.md).

## Paper lifecycle and persistent world state

When a feature creates persistent entities or world state, identify the owner and review the relevant cases:

- startup discovery and reconstruction from saved metadata;
- chunk/entity load and unload, including stale or malformed metadata;
- normal completion, removal, plugin disable, and reload;
- scheduled tasks and listeners, including how their lifetime is bounded;
- repeated lifecycle events and whether cleanup/reconstruction is safe to repeat.

Choose evidence for the actual risk. Pure unit tests can cover state transitions and calculations; MockBukkit can cover supported event wiring; a live-server smoke check may be needed for real chunk/entity behavior. State which layer was exercised and do not claim that one proves another.

## Cross-plugin contracts

- Prefer a published API or an explicit integration contract over reaching into another plugin's private implementation.
- Prefer typed imports and Gradle dependencies over reflection. Use `Class.forName`, reflective method/field lookup, or MethodHandles only when there is no published API, no Maven artifact you can `compileOnly`, and no shared SneakyUtils helper that already owns the integration. Optional plugins that publish Team-Sneakymouse or public Maven artifacts still take `compileOnly` imports plus `PluginManager` enablement checks; do not use reflection merely to avoid declaring a soft dependency. **NMS / CraftBukkit internals are an allowed exception:** keep reflective access there rather than forcing paperweight-typed imports for volatility that already requires per-version maintenance.
- Shared PlaceholderAPI expansion belongs in SneakyUtils `PlaceholderUtil` (consumers that already depend on SneakyUtils should not add a local PAPI dependency or reflective `setPlaceholders` solely for that). Character-name presentation still uses `PlayerUtil.getCharacterName`. See [placeholders](./sneakyutils.md#placeholders).
- If reflection against private internals is the only practical option, document the dependency, the expected members/version assumptions, the user-visible fallback, and how incompatibility is reported. Keep failure bounded so an optional integration does not disable unrelated plugin behavior.
- Treat a new hard dependency, API surface, or persisted cross-plugin format as a compatibility decision. Follow the repository's dependency and approval rules before broadening it.

## Configuration changes

For a substantial configuration change, review defaults, missing or invalid values, bounds, and reload behavior. Keep example/default configuration, parsing, and user documentation aligned where the repository maintains them separately. Prefer clear fallback behavior and actionable diagnostics for values operators can edit. A schema or validation framework is not required unless the project needs it.

## Review outcome

For nontrivial changes, capture material maintainability decisions in review or delivery notes: important ownership/boundary choices, lifecycle cases checked, compatibility assumptions, and evidence gaps. Keep this proportional; a small feature needs no separate design document.
