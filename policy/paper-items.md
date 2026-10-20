# Paper items and displays (LoM)

Load when the ask is a **custom look**, a **server resource pack**, or **ItemDisplay** place/orient. Prefer the matching branch; leave `src/` alone when `run/` or a data component is enough.

## Custom look

CraftEngine (or pack) item ids are **model keys**, not a plugin API.

- Build a normal Bukkit/Paper stack (usually `Material.PAPER`).
- Set `item_model` / `ItemMeta.itemModel` to the id (`NamespacedKey`, e.g. `lom:racing_ring`).
- Names and lore: SneakyUtils `TextUtility` — `&a` name, `&7` tooltip.
- Wearables: Paper `DataComponentTypes.EQUIPPABLE` (e.g. `HEAD`), not a real armor material required for the look.
- Detect by `item_model` and/or plugin PDC. Do **not** add CraftEngine as `compileOnly`, call its item manager, or dig its API unless the user asks for CraftEngine integration.

## Server resource pack

When the ask is “serve a pack” or “blank pack with this model”:

- Put assets under `run/` (or point `server.properties` `resource-pack=` at a URL/zip).
- Do **not** add plugin pack-host services, pack-build scripts wired into the plugin, or new config keys for hosting unless the user asks the plugin to host the pack.

## ItemDisplay place

Defaults that matched live racing-ring playtesting; override only when the user says otherwise:

- Spawn at the **player eye** location (not the clicked block).
- **Yaw** = player yaw.
- **Pitch** = player pitch; if sneaking, pitch `0`.
- Consume the place item except in **creative**.
- Handle air right-click (`PlayerInteractEvent`, often `ignoreCancelled = false`) so placement is not block-hit only.
