# SneakyVariables (generic player data)

Load when a Paper plugin needs **persistent generic player / character / global numbers or strings** (or per-block values of those), shared across servers on the same database. **SneakyVariables** (`Team-Sneakymouse/SneakyVariables`) owns storage, leases, and the Java API. MagicSpells variable YAML still defines Magics names; values live here. Design and protocol: [SneakyVariables `docs/design.md`](https://github.com/Team-Sneakymouse/SneakyVariables/blob/main/docs/design.md). Live switch steps: [cutover runbook](https://github.com/Team-Sneakymouse/SneakyVariables/blob/main/docs/live-cutover.md).

## Use (consumer plugins)

1. Prefer `SneakyVariables.api()` over MagicSpells `VariableManager`, PocketBase copies, flat files, or a private table for the same kind of data.
2. Depend with `compileOnly("io.github.team-sneakymouse:sneakyvariables:<published-version>")` from `https://maven.sneakyrp.com/sneakymouse` ([Maven access](./maven-access.md)). Use the newest published version from Maven metadata ([choosing a version](./maven-access.md#choosing-a-version)) — do not invent coordinates.
3. Declare a required server dependency that loads **before** your plugin (`paper-plugin.yml` / `plugin.yml` `depend`), with `join-classpath: true` when using the paper-plugin form.
4. Online reads/writes (`player`, `character`, `global`) only on the **main thread**. Offline / any-owner work uses `offline()` and must not block the main thread waiting on those futures.
5. Register definitions you own with `define(plugin, …)` on enable (and after your reload); call `undefineAll(plugin)` on disable or before re-registering. Writing an undefined name is refused. Two plugins defining the same name with different scope/kind is a load error.
6. Enumerate registered names with `definitionNames()` (snapshot). Do not call Magics `getVariableManager().getVariables()` for that.
7. Listen to `VariableChangeEvent` when you need to react to changes from any plugin or server (bars, boards, side effects).

Done when: the consumer builds against a published artifact, declares the runtime dependency, and has no Magics-variable bridge, PocketBase mirror, or local persistence for the same values.

## What SneakyVariables owns (do not reimplement)

- PostgreSQL storage through SneakyDB (schema `sneakyvariables`, migrations in the plugin jar).
- Online cache, leases, Velocity handoff, inbox for writes to an owner held elsewhere, and global write-through + `NOTIFY`.
- Bounds, defaults, and persistence flags from definitions.
- Cross-plugin Java API under `com.sneakyvariables.api` (no Kotlin types in signatures; see [cross-plugin API rule](./paper-plugin-maintainability.md#language-java-and-kotlin)).

MagicSpells still owns YAML parsing for its variables, boss/exp bars, scoreboard objectives, meta/computed variables, and `/ms variable` UX. Those call into SneakyVariables for stored values.

## External writers (psql-hooks and other services)

Services outside the plugin change values only with the SQL in the design doc (atomic upsert/add + `NOTIFY`). Do not update `owner_values` without notifying. Donation `globalXpBonus` and allowlisted global reads go through **psql-hooks** (`/internal/lom/variables/...`); see `psql-hooks/AGENTS.md`.

## Verification

Unit and PostgreSQL lease tests live in SneakyVariables. Consumer changes: compile against the published API and spot-check the values you own on a Dev server that already runs SneakyVariables. Live cutover is an operator runbook, not a consumer PR checklist.
