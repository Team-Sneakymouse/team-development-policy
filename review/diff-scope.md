# Diff scope (review judgement)

Use during review when the request was narrow and the diff looks wide. These are judgement calls, not mechanical lint.

## Pack or ops-only ask

Fail when the user asked only to serve or install a resource pack (or similar `run/` / `server.properties` ops) and the diff adds plugin services, pack-build wiring under `src/`, or hosting config the user did not request.

## Custom look / CraftEngine model id

Fail when the user named a CraftEngine or pack model id for a give/detect/look change and the diff adds a CraftEngine dependency or item-manager API, instead of `item_model` (and TextUtility / equippable as needed).

## Pass shape

A pass keeps the change on the smallest surface that satisfies the ask (`run/` + properties, or Paper item components on existing builders) and leaves unrelated modules untouched.
