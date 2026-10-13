# Agent adapters

**UNAPPROVED DRAFT — examples only; no files here are installed.**

Adapters translate discovery, not policy meaning. All agents should load the same pinned policy documents plus local project facts. The proposed project payload is `.team-policy/` with a revision manifest, core/testing policy, workflow, and selected optional skills. Whether this payload is committed is an approval decision; the default proposal is a committed project snapshot for reproducibility.

[Bootstrap example](examples/bootstrap.md) is plain content for integration into native instruction files after approval. It is not itself an automatically discovered instruction file.

## Hermes

Candidate: project `AGENTS.md` plus an optional team-owned skill installed only into the selected Hermes profile. The current official context documentation describes priority between context types; an existing `.hermes.md` or override can shadow the intended bootstrap. Detect those conflicts, and verify loaded instructions in a fresh session. Do not use home-level `AGENTS.md` as a universal solution or modify `SOUL.md` to distribute team development policy. Mother Mouse requires explicit approval of a selected profile before installation.

## Codex

Candidate: repository `AGENTS.md` containing the bootstrap and local facts. Official guidance describes root-to-working-directory discovery and `AGENTS.override.md` overrides. Check nested and global instructions; do not overwrite them. Global instructions must scope the team policy to enrolled projects, not every repository on the machine.

## Cursor

Candidate: project `.cursor/rules/team-policy.mdc` with `alwaysApply: true` to load the bootstrap, or a validated project `AGENTS.md` integration. [MDC example](examples/cursor-rule.mdc) is inert in this repository. Keep optional testing procedures conditional, rather than always loading detailed test rules. Avoid installing both paths with duplicated/conflicting policy.

## Claude Code

Candidate: project `CLAUDE.md` containing explicit read instructions for the project payload and local facts. Native import syntax and user-level discovery need verification on selected versions; the adapter does not depend on an assumed cross-agent import syntax. Official memory documentation could not be retrieved in this draft environment (HTTP 403). This mapping is provisional; no Claude Code runtime validation has occurred.

## Antigravity

Provide the [plain bootstrap example](examples/bootstrap.md) as candidate content for its native rules mechanism. The documented rules/workflows URL yielded only a client-rendered shell in this environment. No native file path or global-memory location is asserted as verified. Confirm rule scope, activation, paths, and fresh-session loading in the product before generating install targets. Antigravity is included in design scope but its executable adapter remains blocked on that validation.

## Conformance for every adapter

- Show the pinned revision and source files in a fresh session, without relying on past conversation memory.
- Demonstrate that core policy loads; a bare link without a read/discovery mechanism is not enough.
- Run the tiny-edit and high-risk scenarios from [review scenarios](../review/scenarios.md).
- Check conflicts, nested projects, existing personal rules, product limits, and selected OS.
- Mark unsupported versions/platforms clearly; never claim support based on writing a file alone.

## Sources and limits

- [Hermes context files](https://hermes-agent.nousresearch.com/docs/user-guide/features/context-files): retrieved for this draft; use live docs rather than older local skill summaries.
- [Codex AGENTS.md](https://developers.openai.com/codex/guides/agents-md): retrieved for this draft.
- [Cursor rules](https://cursor.com/docs/context/rules): retrieved for this draft.
- [Claude Code memory](https://code.claude.com/docs/en/memory): retrieval blocked; validation pending.
- [Antigravity rules/workflows](https://antigravity.google/docs/rules-workflows): usable content unavailable; validation pending.

Documentation lookup is not runtime proof. Product versions and developer OSes remain open review questions.
