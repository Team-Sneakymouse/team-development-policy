# Installation design

Specification only. No installer or runnable install commands exist yet.

## Contract

Input: selected agent(s), project(s), OS, and (for Hermes) profile; enrollment mode (default: sibling-checkout pointer). Default mode should be dry-run. Evaluation must never write to active profiles or real projects without explicit consent.

No network execution pipes that bypass the developer's Git credentials, credentials distribution, permission changes, or silent memory writes.

### Source of truth after enrollment (sibling-checkout)

The installer writes `.team-policy/pointer.json` and a managed bootstrap block. Agents then:

1. Resolve a local checkout from `local_candidates` or clone `remote`.
2. Fast-forward `track_branch` when behind and safe.
3. Read policy documents from that checkout.

A committed file-snapshot payload (schema v1) remains an optional alternate for environments without a shared multi-repo folder.

## Proposed flow

1. **Resolve:** authenticate through the developer's existing Git credentials for this private repo. Confirm the track branch or pinned ref exists.
2. **Detect:** identify agent/version/OS, project root, current instructions, overrides, managed controls, available native mechanisms, and whether a sibling policy checkout already exists. Unsupported targets receive a blocker, not a guessed path.
3. **Plan:** display every target, bootstrap/pointer modification, candidate paths, and existing-rule conflict. Ask for explicit write consent; plan mode never writes to active profiles or real projects.
4. **Materialize pointer:** write `.team-policy/pointer.json` (schema v2). Optionally ensure the first `local_candidates` path is a clone of this repo. Do not copy the full policy tree into the plugin by default.
5. **Integrate:** add a managed bootstrap block to native instruction files, preserving all unrelated content. Refuse ambiguous edits. Local project facts stay outside managed policy. Conversational memory, if supported, may store a discovery pointer but is not the source of truth.
6. **Commit locally where requested:** present the diff; a pointer/bootstrap commit requires explicit agreement. Do not auto-commit unrelated files or push/modify plugin repositories as part of installation without authorization.
7. **Verify:** confirm pointer + bootstrap presence; in a fresh agent session, confirm the agent resolves the checkout, can read `policy/core.md`, and follows a scoped task. Report file materialization separately from product-level validation.

## State, update, rollback

Pointer should include schema version, mode, source repo, remote, track branch (or pinned ref), and local candidate paths. Avoid machine-specific absolute paths in committed pointers; resolution is relative to the project root.

- Re-running enrollment with the same pointer is idempotent.
- Policy content updates happen by pulling the sibling checkout (or changing track/pin), not by rewriting copied files in every plugin.
- Abort or require a reviewed merge if the managed bootstrap block changed locally.
- Uninstall removes only unchanged installer-owned bootstrap/pointer content; modified content is preserved with a report.
- Keep secret material out of pointers/backups and never overwrite other Hermes profiles.

## Future isolated acceptance tests

Missing sibling → clone; already present → no duplicate clone; behind track branch → fast-forward; dirty policy checkout → report/ask; shadowing override detection; unknown agent version; no credentials; inaccessible private repo; fresh-session discovery; Windows/macOS/Linux paths once the team selects targets.

These are proposed tests, not completed test results. Installer implementation starts only after design review.
