# Agent adapters

`examples/` holds the canonical stub files for enrolled projects: the managed `AGENTS.md` block ([bootstrap](examples/bootstrap.md)), [`CLAUDE.md`](examples/CLAUDE.md), [Cursor rule](examples/cursor-rule.mdc), [Copilot instructions](examples/copilot-instructions.md), and [pointer](examples/pointer.json). Edit them here; [`installer/sync-stubs.ps1`](../installer/sync-stubs.ps1) writes them into projects. Nothing in this repository loads them.

Adapters translate discovery, not policy meaning. All agents should load the same policy documents from a resolved checkout of this repository, plus local project facts.

## Source of truth

Default enrollment mode: **sibling checkout**.

- **Runtime:** agents resolve a local clone of `Team-Sneakymouse/team-development-policy` using `.team-policy/pointer.json` (`local_candidates`, then clone `remote` if missing). They read `policy/`, `workflows/`, and optional `skills/` from that checkout.
- **Stay current:** before implementation work (not read-only investigation), fast-forward the checkout when it is clean and behind `origin/<track_branch>`. Do not invent policy from memory, a web mirror, or an unlisted path.
- **Track branch:** pilots track `main` of this repo. Pinning an immutable tag/commit remains available for locked evaluations; say so in the pointer if used.
- **Optional alternate:** a committed project `.team-policy/` file snapshot (schema v1) for machines without a multi-repo workspace. Prefer the sibling pointer for LoM developer machines.

Every native instruction file in a project is a pointer to `AGENTS.md`; the [bootstrap block](examples/bootstrap.md) and local facts live only there, so the pointers never describe content that can drift.

## Hermes

Candidate: project `AGENTS.md` plus an optional team-owned skill installed only into the selected Hermes profile. The current official context documentation describes priority between context types; an existing `.hermes.md` or override can shadow the intended bootstrap. Detect those conflicts, and verify loaded instructions in a fresh session. Do not use home-level `AGENTS.md` as a universal solution or modify `SOUL.md` to distribute team development policy. Org-operated Hermes profiles (for example Mother Mouse) require explicit selection of that profile before any install into it.

## Codex

Candidate: repository `AGENTS.md` containing the bootstrap and local facts. Official guidance describes root-to-working-directory discovery and `AGENTS.override.md` overrides. Check nested and global instructions; do not overwrite them. Global instructions must scope the team policy to enrolled projects, not every repository on the machine.

## Cursor

Candidate: project `.cursor/rules/team-policy.mdc` with `alwaysApply: true` pointing at `AGENTS.md` (which holds the managed bootstrap), or an inline bootstrap. The [canonical rule](examples/cursor-rule.mdc) sits outside `.cursor/rules/`, so it is inert in this repository. Keep optional testing procedures conditional. Avoid installing both paths with duplicated/conflicting policy.

## Claude Code

Project `CLAUDE.md` containing only `@AGENTS.md` ([example](examples/CLAUDE.md)). Claude Code imports the referenced file at session start, so the managed bootstrap and local facts live in `AGENTS.md` alone. **Design-scope only** until fresh-session validation succeeds.

## Antigravity

Provide the [plain bootstrap example](examples/bootstrap.md) as candidate content for its native rules mechanism. The documented rules/workflows URL yielded only a client-rendered shell in this environment. No native file path or global-memory location is asserted as verified. Confirm rule scope, activation, paths, and fresh-session loading in the product before generating install targets. **Design-scope only**; executable adapter blocked on that validation.

## Conformance for every adapter

- Resolve the policy checkout from the pointer (existing sibling, pull-when-behind, or clone) in a fresh session without relying on past conversation memory.
- Demonstrate that core policy loads via the thin bootstrap; further docs load on branch as specified.
- Run the tiny-edit and high-risk scenarios from [review scenarios](../review/scenarios.md).
- Check conflicts, nested projects, existing personal rules, product limits, and selected OS.
- Mark unsupported versions/platforms clearly; never claim support based on writing a file alone.

## Sources and limits

- [Hermes context files](https://hermes-agent.nousresearch.com/docs/user-guide/features/context-files): retrieved during authoring; use live docs rather than older local skill summaries.
- [Codex AGENTS.md](https://developers.openai.com/codex/guides/agents-md): retrieved during authoring.
- [Cursor rules](https://cursor.com/docs/context/rules): retrieved during authoring.
- [Claude Code memory](https://code.claude.com/docs/en/memory): `@path` imports in `CLAUDE.md`; fresh-session validation pending.
- [Antigravity rules/workflows](https://antigravity.google/docs/rules-workflows): usable content unavailable; validation pending.

Documentation lookup is not runtime proof. No adapter is conformance-verified yet. Product versions and developer OSes remain open review questions.
