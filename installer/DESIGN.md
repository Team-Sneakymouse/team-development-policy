# Installation design

**UNAPPROVED DRAFT — specification only. No installer or runnable install commands exist.**

## Contract

Input: an explicitly approved immutable policy revision; selected agent(s), project(s), OS, and (for Hermes) profile. Default mode should be dry-run. Installing a reviewed-but-unapproved draft must fail unless a separate isolated evaluation mode is explicitly selected; evaluation must never write to active profiles or real projects.

No network execution pipes, implicit latest-version updates, credentials distribution, permission changes, or silent memory writes.

## Proposed flow

1. **Resolve:** authenticate through the developer's existing Git credentials for this private repo. Fetch an immutable approved commit and verify its approval record and file hashes. Hashes establish integrity, not approval; the approval authority and release-signing approach are still decisions to make.
2. **Detect:** identify agent/version/OS, project root, current instructions, overrides, managed controls, and available native mechanisms. Unsupported targets receive a blocker, not a guessed path.
3. **Plan:** display every target, modification, selected revision, existing-rule conflict, and backup. Ask for explicit write consent; no active writes occur during this first-draft effort.
4. **Materialize:** stage the project `.team-policy/` payload and optional user-local cache. Generated files identify source revision, managed block ownership, and draft/approved status. Keep global enrollments limited to opted-in projects.
5. **Integrate:** add a managed bootstrap block to native instruction files, preserving all unrelated content. Refuse ambiguous edits. Local project facts stay outside managed policy. Conversational memory, if supported, may store a discovery pointer but is not the source of truth.
6. **Commit locally where requested:** present the diff; a project snapshot/bootstrap commit requires explicit agreement. Do not auto-commit unrelated files or push/modify plugin repositories as part of installation without authorization.
7. **Verify:** inspect written files and launch a fresh agent session in an isolated test project. Confirm policy revision, actual discovery, and scoped task behavior. Report file materialization separately from product-level validation.

## State, update, rollback

Manifest should include source repo, immutable revision, approval reference, adapter/version, project root, selected profile if applicable, installed file hashes, and managed-block identifiers. Avoid machine-specific paths in committed portable manifests; store machine-local resolution separately.

- Reinstalling the same revision is idempotent.
- Updates are explicit, show a diff, preserve user edits, and never switch to latest silently.
- Abort or require a reviewed merge if owned content changed locally.
- Roll back using recorded snapshots. Uninstall removes only unchanged installer-owned content; modified content is preserved with a report.
- Stage and validate before writes; multi-file failure must restore the prior state or clearly report partial failure with recovery steps.
- Keep secret material out of manifests/backups and never overwrite other Hermes profiles.

## Future isolated acceptance tests

Clean install; idempotency; existing instruction preservation; shadowing override detection; unknown agent version; missing approval; no credentials; inaccessible private repo; changed managed block; stale revision; interrupted multi-file write; rollback; uninstall preservation; fresh-session discovery; Windows/macOS/Linux paths once the team selects targets.

These are proposed tests, not completed test results. Installer implementation starts only after design review.
