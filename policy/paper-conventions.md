# Paper plugin conventions

Baseline rules for any change to a Team-Sneakymouse Paper plugin, however small. For larger design questions, see [Paper plugin maintainability](./paper-plugin-maintainability.md).

- **Main thread:** do disk, database, Pocketbase and HTTP calls in async tasks; return to the main thread only to touch Bukkit state. No blocking calls in event handlers.
- **Reload:** when adding config fields, caches, tasks or listeners, clear and rebuild them in the reload path. Cancel old scheduled tasks before starting new ones.
- **Block damage:** any plugin that causes block damage must route it through SneakyUtils' shared `AlteredBlockManager`, obtained via `SneakyUtils.getAlteredBlockManager()`. Do not bypass shared tracking or introduce a separate restoration manager. See [block damage and restoration](./sneakyutils.md#block-damage-and-restoration).
- **Public hooks:** MagicSpells spell names, variables and dispatched console commands are an API used by MagicSpells-Data (branch `dev`) and other plugins. Search those callers before renaming or changing arguments.
- **Player-facing names:** show character names via SneakyUtils `PlayerNameUtils.getCharacterName(player)`, not Minecraft account names. The only exceptions are admin/moderation tools and command auto-completion, which may use Minecraft names. See [the shared getter contract](./sneakyutils.md#player-facing-character-names).
- **Stable ids:** don't rename `lom:` `item_model` ids or PDC keys; existing items and entities depend on them. Add a migration or keep the old key.
- **Docs:** when commands, permissions or config keys change, update the relevant documentation in the same commit. Update AGENTS.md only when its instructions or context pointers change; keep shared conventions in this policy and implementation details beside the code or in task-specific documentation.
