# SneakyUtils (shared Paper utilities)

Team-Sneakymouse Paper plugins share portable helpers and in-memory managers through **SneakyUtils** (`Team-Sneakymouse/SneakyUtils`). It is a live Paper plugin on the server, not a shade-only library. Repo-local build facts and `SneakyUtils/AGENTS.md` own architecture details; this policy owns when to **use** and **contribute**.

## Use (consumer plugins)

When editing a Team-Sneakymouse Paper plugin:

1. Prefer existing `com.sneakyutils.util.*` APIs (and managers such as `AlteredBlockManager`) over new local copies of the same helper.
2. Depend with `compileOnly("io.github.team-sneakymouse:sneakyutils:<published-version>")` from `https://maven.sneakyrp.com/releases`. Resolve the version from Maven metadata or an existing peer plugin — do not invent coordinates.
3. Declare a server load-before / `depend` on plugin `SneakyUtils` so classes and manager memory exist at runtime.
4. Keep domain-specific helpers in the consumer. Thin wrappers that call SneakyUtils and add plugin-only behavior are fine; duplicated TextUtility/ChatUtility/InventoryUtility implementations are not.
5. For MagicsSpells temporary blocks and related undo, use `SneakyUtils.getAlteredBlockManager()` (or MagicsSpells’ facade that delegates to it). Do not reintroduce a second in-plugin altered-block manager.

Done when: the consumer builds against a published artifact, declares the runtime dependency, and has no fresh duplicate of a shared util already in SneakyUtils.

## Player-facing character names

All player-facing names identifying players (messages, menus, labels, scoreboards, and similar output) must use character names instead of Minecraft account names. The only exceptions are **admin/moderation tools** and **command auto-completion**, which may use Minecraft names. An ordinary player command's response is still player-facing output; the completion exception does not extend to that response.

Use `com.sneakyutils.util.PlayerNameUtils.getCharacterName(player)` rather than `player.getName()` / `player.name`, a local SCM bridge, or a PlaceholderAPI workaround. Call it on the **server thread**; capture the returned string there before any asynchronous work that needs it. Insert the result as literal text, not as MiniMessage or placeholder input.

The getter reads the current character name without caching, strips angle-bracket tags and legacy/hex formatting, and returns plain text (not the display name's prefix/title/gender suffix). Its built-in fallback is the Minecraft name when SCM is absent, disabled, incompatible, or has no usable character/name after sanitization. This is the shared getter's availability fallback, not permission to bypass it for ordinary player-facing output. No new SCM or PlaceholderAPI dependency is required; retain the consumer's normal SneakyUtils runtime dependency and use a published version containing the getter.

Getter contract checked against [SneakyUtils `2d747d631c740f9bf5478086a182a510391b1a9b`](https://github.com/Team-Sneakymouse/SneakyUtils/blob/2d747d631c740f9bf5478086a182a510391b1a9b/src/main/kotlin/com/sneakyutils/util/PlayerNameUtils.kt). Character names are presentation, not stable identifiers; do not replace UUIDs or account-based lookup contracts with character-name keys.

## Contribute (expanding the shared plugin)

When a helper would serve **more than one** Team-Sneakymouse Paper plugin, or already exists as near-copies across plugins:

1. Add or extend it in the **SneakyUtils** repository under `com.sneakyutils.util` (or a manager package when working memory / listeners are required).
2. Accept only portable code: Bukkit/Paper/Adventure/Java (and declared soft deps). No MagicsSpells spell types, no consumer plugin singletons, no game-mode domain models.
3. Cover behavior with tests in SneakyUtils; run `./gradlew check`; publish via the repo’s normal `main` publish flow before pinning a new version in consumers.
4. Migrate consumers to the published version in a follow-up (or the same authorized multi-repo task). Leave MagicsSpells-only or single-plugin peels until a second consumer needs them.

Ask before: large MagicsSpells peels, changing marker/PDC identity, or forcing a hard depend on plugins that only need static helpers at compile time in unusual loaders.

Done when: the shared API is published, tested, and at least the requesting consumer (preferably peers with copies) depends on it.

## What stays local

Plugin feature managers, protocol/proxy messaging, PocketBase clients, MagicsSpells spell/item/config domain types, and one-off helpers with a single consumer stay in that plugin until a second real consumer appears.
