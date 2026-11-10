# SneakyCosmetics (things worn on players)

Load when a Paper plugin puts a **model on a player** that isn't in an equipment slot: a backpack, shell, wings-style prop, hat over a helmet, or anything else drawn as an `ItemDisplay` (or other display entity) **riding the player** and following their body or head. **SneakyCosmetics** (`Team-Sneakymouse/SneakyCosmetics`) owns this; its `README.md` documents the API. This policy says when to use it and what not to rebuild locally.

## Use

1. Wear it through SneakyCosmetics: `SneakyCosmetics.getBackItems()` for things turned with the **body** (back, waist), `SneakyCosmetics.getHeadItems()` for things turned and nodded with the **head** (hats, drawn like a head-slot item). Use a namespaced key of your plugin (`<plugin>:<thing>`).
2. Call `wear` **once** when the player should start wearing it, and `takeOff` when they should stop (race change, a disguise/form that replaces it, reload/disable). Use `wears(uuid, key)` to check. Do not re-wear every tick and do not keep a parallel `UUID → ItemDisplay` map; `worn(player, key)` and `displays(key)` give you the entity for tags, diagnostics counts or tests.
3. Express where it sits as a `Placement`. A pose tuned from the seat (top of the head) is `BackItems.Placement.fromSeat(transformation)`; per-variant model offsets/turns belong in that transformation. Keep operator-tunable numbers in your config and build the placement from them.
4. Depend on it: `compileOnly("io.github.team-sneakymouse:sneakycosmetics:<published-version>")` (`isTransitive = false`) from `https://maven.sneakyrp.com/releases`, a hard runtime `depend` on plugin `SneakyCosmetics`, and stage it for `runServer` like other hard deps.

## What SneakyCosmetics owns (do not reimplement)

- Spawning a non-persistent display, mounting it, and its cleanup on quit/disable.
- Keeping it on: remount after a teleport/dismount, respawn after a world change or removal; leave it alone while it rides something else (SneakyUtils' camera watch moves riders onto the watcher's body).
- Turning: the **display's own yaw** (eased by its teleport duration) with the transformation in that frame. Do not rotate a display about the player by putting the yaw into the transformation's rotation: the client eases translation in a straight line and rotation round an arc, so offset models cut through the body on fast turns.
- The client's **body-yaw** rule (`BodyTracker`; the server's player body yaw does not match what clients draw) and the head-slot nod math.
- Not drawing it while the wearer is dead, invisible, a spectator, or lying/swimming/gliding (`hideLying`), and per-viewer visibility: hidden from viewers who can't see the wearer and from the wearer unless `showToWearer` (default off for head items).

If a cosmetic needs behavior SneakyCosmetics lacks (a new attachment point, a new hide rule, lead/prediction), **add it to SneakyCosmetics** with tests and publish it, then use it; do not fork the engine into the consumer. Plugin-specific conditions about *who* wears it and *when* (race, form, minigame state) stay in the consumer.

## Cross-plugin API shape

Every Team-Sneakymouse Kotlin plugin shades its own Kotlin stdlib, so a public API called by another plugin must not put **Kotlin types** in its signatures: no Kotlin function types (`(T) -> Unit`), no default arguments without `@JvmOverloads`, no reliance on `DefaultConstructorMarker`. Use `java.util.function.*`, explicit overloads, and Java-callable builders/`with` methods. Calls that pass Kotlin types between plugins fail at runtime with `LinkageError` even though they compile. Static entry points get `@JvmStatic`.

Keep published signatures **binary compatible**: consumers are pinned to older versions while the server runs the newest SneakyCosmetics. Append parameters (never reorder), keep the old constructor/overloads, and when a method moves to a generic base class, redeclare it in the subclass so the old descriptor still exists. Check with `javap` against the compiled class.

## Verification

Pose math (`BackItems.pose`, `HeadItems.pose`) is pure and unit-tested in SneakyCosmetics. How a cosmetic looks on a moving player, hide/remount behavior and viewer visibility need a live check (`runServer` or a test server) with a second client; say which layer you exercised.

Done when: the consumer wears through SneakyCosmetics, depends on a published version, and has no local display spawning, body-yaw tracking, remount, or visibility loop for the worn item.
