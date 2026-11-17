# Database migrations

Load when a change adds, changes or reads a plugin's database tables through SneakyDB.

Plugins own their schema: each plugin ships numbered SQL scripts in its jar, and SneakyDB runs them at server startup until the database matches the plugin. SneakyDB's README ([Migrations](https://github.com/Team-Sneakymouse/SneakyDB#migrations)) documents the API and how failures are reported; this page holds the rules a plugin author follows. A schema change is high risk under [Scope and testing](./scope-and-testing.md).

## How it works

- Scripts live in the jar under `db/migrations/`, named `V<number>__<name>.sql` (`V001__init.sql`). Numbers start at 1 with no gaps. The plugin's schema version is its highest script number; there is no separate constant.
- During enable, the plugin calls `SneakyDBProvider.getApi().migrate(IDENTIFIER, MyPlugin::class.java)` with its existing stable id constant, and does no work on its own tables until the returned future completes.
- When that future fails, the plugin stays inert: it starts nothing that uses its tables and does not retry. SneakyDB does not disable the plugin or refuse its calls, so this is the plugin's own job. The server thread waits while migrations run, so the future's callback hands work to the scheduler and never blocks until the server thread has done something.
- SneakyDB collects every plugin's scripts during enable and runs them after all plugins have registered, each script in its own transaction, recording them in one central table per database. The server does not finish starting, and accepts no players, until that has finished.
- A script that fails while it runs stops the server, so errors don't compound. A problem found before any of a plugin's scripts ran (an order that can't be resolved, a jar older than the database, an edited script) fails only that plugin, and the server comes up in maintenance until an operator has fixed it.
- There are three databases. Dev runs a script once the plugin is published and the dev server restarts, Staging once the plugin is accepted for the next release, and Live at the first restart of a release rollout.

## Writing a script

- **No transaction control:** SneakyDB supplies one transaction per script, so write no `BEGIN`/`COMMIT` and nothing that can't run inside a transaction, such as `CREATE INDEX CONCURRENTLY`.
- **Never edit a merged script**, not even whitespace or a comment: SneakyDB compares checksums and the plugin stops loading on a mismatch. Fix a mistake with a new script.
- **Forward only:** there are no down scripts. An undo is a new script or a restore from backup.
- **Renumber on conflict:** if another pull request merged the same number first, renumber yours before merging, so the sequence keeps no gaps or duplicates.
- **No schemas:** a script never creates or drops a schema. Ask the operator for a new schema before the plugin's first script that needs it reaches Dev.
- **Only your own tables:** a plugin's tables change only through its own scripts. A change another plugin needs in your tables goes into your repository, and one you need in theirs goes into theirs.
- **No schema statements in plugin code:** once a plugin uses migrations, its scripts are the only place its schema is defined. Remove startup `CREATE TABLE IF NOT EXISTS` and any other DDL outside `db/migrations/`.
- **Write for Live's data, not an empty database:** a script must work against a copy of Live. Before adding a constraint or a `NOT NULL` column, decide what happens to existing rows (a default, or a backfill in the same script). Avoid long table rewrites where you can: other servers on the same database wait on the lock while it is held.

## Versions and rollouts

- **Strict versions:** a jar older than the database's version for that plugin does not start. Once a script has run, the previous jar can't be put back, and all servers that share a database run the same plugin versions and restart together.
- **Breaking scripts carry a notice:** a script that breaks older jars (it retypes, renames or drops a column or table) gets this notice at the top of its pull request description, so the rollout stops every server on that database before the first one starts:

  > **Breaking schema change:** `V007__retype_owner.sql` changes `<table>.<column>`, and jars of `<plugin id>` older than this version break once it has run. During the rollout, stop every server on the database before the first one starts with this version.

- **Other plugins' tables wait until after enable:** a plugin does not read or write another plugin's tables during its own enable, because they may be in the middle of a migration.

## Changes that span plugins

- A script that needs another plugin's schema at a certain version says so in its top comment block: `-- requires: <plugin id> >= <version>`, or `-- requires-if-present: <plugin id> >= <version>` when that plugin is optional. SneakyDB orders all plugins' scripts by these lines.
- Aim to merge every pull request of a cross-plugin change and restart once. For that, both sides declare what they need from the other.
- Each pull request of the set lists its sibling pull requests in its description, and the set is tested together against a copy of the data before a rollout.
- `paper-plugin.yml` dependencies stay what they are: presence, load order and class access. They can't express schema versions.
- Renaming a plugin's id needs a manual operator step before the restart, and a plugin that takes over another plugin's tables does so in a script. Raise either with the operator before you start.

### Example: retyping a referenced column

Plugin `b` retypes `b_characters.id`, which plugin `a`'s `a_claims.owner_id` references with a foreign key. The key has to come off before the referenced column changes and go back on after both columns match.

`a`, `V005__drop_owner_fk.sql`:

```sql
ALTER TABLE a_claims DROP CONSTRAINT a_claims_owner_fk;
```

`b`, `V003__retype_character_id.sql`:

```sql
-- requires-if-present: a >= 5
ALTER TABLE b_characters ALTER COLUMN id TYPE uuid USING id::uuid;
```

`a`, `V006__retype_owner.sql`:

```sql
-- requires: b >= 3
ALTER TABLE a_claims ALTER COLUMN owner_id TYPE uuid USING owner_id::uuid;
ALTER TABLE a_claims ADD CONSTRAINT a_claims_owner_fk
    FOREIGN KEY (owner_id) REFERENCES b_characters (id);
```

SneakyDB runs them as `a` 5, `b` 3, `a` 6 in one restart. `b` uses `requires-if-present` because it works without `a` installed. If one of the two pull requests is missed, the order can't be resolved and none of those scripts run. Both pull requests retype a column, so both carry the breaking-change notice and list each other.

## Tests

- A plugin has a test that applies all its scripts in order to an empty PostgreSQL and then exercises its store, without any shared or production database. It comes with the plugin's first script, as an exception to "no new harness without approval" in [Scope and testing](./scope-and-testing.md#scope-boundaries).
- That test proves the scripts apply and match the code; it says nothing about Live's existing rows, which the script itself has to handle.

## Adopting migrations in an existing plugin

- An existing plugin that already has tables adopts this with the operator: its current schema becomes script 1 (or its existing numbered scripts keep their numbers), and the operator records those scripts as already applied in each database before the first jar that calls `migrate` starts there.
- Until a plugin has adopted it, the plugin's existing way of changing its schema stays. A new plugin uses migrations from its first table.
