# Paper items and displays (LoM)

Load when the ask is a **custom look**, **animated model**, a **server resource pack**, or **ItemDisplay** place/orient. Prefer the matching branch; leave `src/` alone when `run/` or a data component is enough.

## Animation: prefer ModelEngine

For anything that needs animation **or would benefit from it**, prefer **ModelEngine** as the visual implementation. Proactively consider animated creatures, props, machines, vehicles, articulated objects, idle motion, and interaction feedback even when the request does not explicitly say “animate.” Explain the useful animation opportunity rather than silently settling for a static model. Prefer authored ModelEngine models/animations over building a bespoke per-bone ItemDisplay/armor-stand rig or plugin-side animation scheduler.

This is a design preference, not permission to expand scope: propose optional animation when it materially adds work, and do not automatically migrate existing static content or add unrelated animation. Plain static `item_model` assets and simple display placement remain appropriate when animation adds no value. If ModelEngine is unsuitable, explain the concrete constraint before choosing a custom animation implementation. Keep gameplay authority and lifecycle ownership in the plugin; verify the target ModelEngine version/API and runtime availability rather than guessing integration calls or dependencies.

Follow the resource repository's [ModelEngine instructions](https://github.com/Team-Sneakymouse/craftengine-resources/blob/main/README.md#modelengine) and [architecture](https://github.com/Team-Sneakymouse/craftengine-resources/blob/main/docs/architecture.md#modelengine):

- Author ModelEngine-compatible Blockbench `.bbmodel` blueprints in **`craftengine-resources/modelengine/blueprints`**, not `resources/modelengine` or a live server folder. This is a separate authored-blueprint path from static Java block/item model exports.
- Blueprint IDs come from lowercase file names; keep names unique across subfolders and preserve existing referenced IDs.
- Do not commit ModelEngine-generated files or build a separate plugin-owned pack pipeline. The existing dev build generates the `modelengine` pack; promotion uses the frozen release and regenerates server models for it.
- Server blueprint directories are replaced by the repository contents during operations: server-only edits are not durable. ModelEngine owns the core entity shaders; do not add competing overrides in other packs.
- Dev's ModelEngine version and configuration are authoritative; production must match. Check the current resource-repository documentation instead of copying a version pin into this policy.

Validate blueprint registration and the plugin/model/animation references through the existing pipeline when authorized. Report pack generation and registration separately from live animation playback, transitions, viewer behavior, and cleanup; a valid `.bbmodel` or successful plugin build alone proves none of those runtime behaviors. Publishing assets or promoting a pack still requires the task's normal authorization.

## Custom look

CraftEngine (or pack) item ids are **model keys**, not a plugin API.

- Build a normal Bukkit/Paper stack (usually `Material.PAPER`).
- Set `item_model` / `ItemMeta.itemModel` to the id (`NamespacedKey`, e.g. `lom:racing_ring`).
- Names and lore: SneakyUtils `TextUtility` — `&a` name, `&7` tooltip.
- Wearables: Paper `DataComponentTypes.EQUIPPABLE` (e.g. `HEAD`), not a real armor material required for the look.
- **Identity (place / use / give):** use **SneakyItems** for definition registry, create/match, and inventory updating. Stamp and match the magic-item PDC key (`PersistentDataType.STRING` = the item internal name, e.g. `item-paladinNetGun`). Live LoM stacks almost always use the historical namespace `magicspells` — `new NamespacedKey("magicspells", "magicitem")` — even when MagicsSpells is only a registering consumer; do not rewrite that namespace on existing items. The defining plugin and the PDC namespace may differ: register with both. Listeners and `isX` helpers read that key only — not `item_model` alone, and not full `ItemStack` / `isSimilar` equality. Config should name the magic-item id (e.g. `magic-item:`) beside the model. Display-only stacks (ItemDisplay visuals with no player use) stay model-only and need no stamp.
- **MagicsSpells** remains a registering consumer: it parses its own `magic-items:` sections and registers them into SneakyItems (typically with PDC namespace `magicspells`). Other plugins should register their own definitions the same way rather than embedding MagicsSpells item parsers. Mass migration of existing stamp helpers is gradual; new code should prefer SneakyItems.
- **Soulbound / expiration:** SneakyItems owns enforcement (`ItemBehaviors`, listeners, `ItemExpireEvent`). Persisted keys stay `magicspells:soulbound_owner` / `magicspells:expires_at`. Creative bypass is `sneakyitems.nosoulbound` plus Creative mode.
- Do **not** add CraftEngine as `compileOnly`, call its item manager, or dig its API unless the user asks for CraftEngine integration.

## Server resource pack

When the ask is “serve a pack” or “blank pack with this model”:

- Put assets under `run/` (or point `server.properties` `resource-pack=` at a URL/zip).
- Do **not** add plugin pack-host services, pack-build scripts wired into the plugin, or new config keys for hosting unless the user asks the plugin to host the pack.

## ItemDisplay place

For a display **worn on a player** (riding them, following body or head), use [SneakyCosmetics](./sneakycosmetics.md) instead of the defaults below.

Defaults that matched live racing-ring playtesting; override only when the user says otherwise:

- Spawn at the **player eye** location (not the clicked block).
- **Yaw** = player yaw.
- **Pitch** = player pitch; if sneaking, pitch `0`.
- Consume the place item except in **creative**.
- Handle air right-click (`PlayerInteractEvent`, often `ignoreCancelled = false`) so placement is not block-hit only.
