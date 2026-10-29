# Paper plugin conventions

Baseline rules for any change to a Team-Sneakymouse Paper plugin, however small. For larger design questions, see [Paper plugin maintainability](./paper-plugin-maintainability.md).

- **Main thread:** do disk, database, Pocketbase and HTTP calls in async tasks; return to the main thread only to touch Bukkit state. No blocking calls in event handlers.
- **Reload:** when adding config fields, caches, tasks or listeners, clear and rebuild them in the reload path. Cancel old scheduled tasks before starting new ones.
- **Public hooks:** MagicSpells spell names, variables and dispatched console commands are an API used by MagicSpells-Data (branch `dev`) and other plugins. Search those callers before renaming or changing arguments.
- **Stable ids:** don't rename `lom:` `item_model` ids or PDC keys; existing items and entities depend on them. Add a migration or keep the old key.
- **Docs:** when commands, permissions or config keys change, update the README and AGENTS.md in the same commit.
