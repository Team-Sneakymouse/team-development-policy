# Team-policy bootstrap (canonical)

The managed block every enrolled project's `AGENTS.md` carries. `installer/sync-stubs.ps1` (or `sync-stubs.sh`) writes it between the markers; edit it here, not in the projects. Keep it thin: the policy README is the index.

When you change the block, first copy the current block (markers included) to a new numbered file in [`installer/retired/bootstrap/`](../../installer/retired/bootstrap/). The sync scripts only replace blocks that match the current or a retired canonical block; any other block counts as locally edited and is left alone.

```markdown
<!-- BEGIN TEAM-POLICY MANAGED BOOTSTRAP -->
This project follows the Team-Sneakymouse development policy, kept in a sibling checkout that `.team-policy/pointer.json` names.

The policy root is the first `local_candidates` path in the pointer, resolved from this project's root, that exists. If none exists, clone the pointer's `remote` into the first candidate with the developer's Git credentials and say so. Before implementation work (not for read-only investigation), run `git fetch` in the checkout, then fast-forward it to `origin/<track_branch>` if it is behind and clean; if the fetch fails or local changes block the fast-forward, report it and ask.

Before implementing, read `<policy-root>/README.md`. It is the policy index and says which documents apply to which kind of change. If the policy root can't be resolved or read, stop and report that instead of working from memory or another copy.

Build commands, architecture facts and recorded local exceptions in this file are authoritative for this repository. Where this file and the policy require incompatible actions, say so before expanding the work. Running checks and writing tests are separate decisions: a source edit does not by itself require a new test.
<!-- END TEAM-POLICY MANAGED BOOTSTRAP -->
```
