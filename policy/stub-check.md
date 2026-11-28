# Stub check

An enrolled project gets its copy of the team-policy stubs when it is created or last synced, and nothing updates that copy afterwards. A project made from an old EmptyPlugin checkout, or one nobody has worked in for a while, can carry outdated stubs. This check runs during normal work, so outdated stubs are caught the next time someone touches the project.

Before you finish an implementation task, run the sync script from the policy checkout as a dry run against the project:

```bash
<policy-root>/installer/sync-stubs.sh --project <project-root>
```

On Windows PowerShell, use `<policy-root>/installer/sync-stubs.ps1 -Project <project-root>`.

- **`up to date`:** nothing to do.
- **`would write …`:** run it again with `--apply` (`-Apply`) and commit the result on its own in the same branch or PR, with a message like `Sync team-policy bootstrap stubs to the canonical versions`. Keep it out of the actual change's commits, so that diff stays readable. The script replaces only text that exactly matches a current or retired canonical version, so it never overwrites local edits.
- **`WARNING: …`:** the script left a file alone because its text is unknown to the script (a custom pointer stub, an edited managed block, broken markers). Don't hand-merge it as part of this task. Name the file in your report and say it needs a look.

Then compare `.team-policy/pointer.json` with [`adapters/examples/pointer.json`](../adapters/examples/pointer.json). The script never touches pointers. If `remote`, `track_branch`, `local_candidates` or `schema_version` differ, report it and don't edit the pointer.

Same skips as [With your next change](./next-change.md): skip this when the task's scope limit excludes it ("one line only") or when the change is docs-only, and say so in the report. Like those migrations, this is in scope for any implementation task, as an exception to "keep unrelated cleanup out of scope" in [core policy](./core.md).
