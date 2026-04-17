# cvn-clothingitems

Metadata driven clothing items for `ox_inventory` + `4bit_appearance`.

This resource uses a small set of generic inventory items (`clothing_jacket`, `clothing_pants`, etc.) and stores the real outfit data in item metadata (`drawable`, `texture`, `collection`, labels, and icons).

## Features

- Use clothing items from `ox_inventory` with `client.event = "cvn-clothingitems:client:use"`.
- Apply metadata based components and props (`metadata.components`, `metadata.props`).
- Auto give clothing items when a player confirms clothing changes in `4bit_appearance`.
- Outfit bag flow with charge consumption (`outfit_bag` + `outfit_change_charge`).
- Optional donation box and trash can station zones.
- Optional preset clothing set giver export/command.
- Variant lookup commands from `4bit_appearance/public/shared/variantsMetadata.json`.

## Requirements

1. `ox_lib`
2. `ox_inventory`
3. `4bit_appearance`

`fxmanifest.lua` already loads:
- `config.lua`
- `client/main.lua`
- `client/outfitbag.lua`
- `client/stations.lua`
- `server/main.lua`
- `server/outfitbag.lua`
- `server/stations.lua`

## Installation

1. Put this resource in your resources folder.
2. Copy the items from the items.lua and put them into your ox items.lua
3. Ensure startup order includes dependencies before this resource.
4. Restart your server.

## Generic Item List

Base generic items used by this system:
- `clothing_jacket`
- `clothing_pants`
- `clothing_shoes`
- `clothing_undershirt`
- `clothing_torso`
- `clothing_vest`
- `clothing_mask`
- `clothing_hat`
- `clothing_glasses`
- `clothing_ears`
- `clothing_bag`
- `clothing_accessory`
- `clothing_watch`
- `clothing_bracelet`
- `clothing_decal`
- `outfit_bag`
- `outfit_change_charge`

## Metadata Examples

Jacket item with bundled torso:
```lua
exports.ox_inventory:AddItem(playerId, 'clothing_jacket', 1, {
    label = 'Blue Jacket',
    image = 'shirt',
    components = {
        { component = 3, male = { drawable = 0, texture = 0 }, female = { drawable = 0, texture = 0 } },
        { component = 11, male = { drawable = 544, texture = 1 }, female = { drawable = 588, texture = 1 } },
    },
})
```

Hat prop item:
```lua
exports.ox_inventory:AddItem(playerId, 'clothing_hat', 1, {
    label = 'Black Cap',
    image = 'hat',
    props = {
        { prop = 0, male = { drawable = 10, texture = 0 }, female = { drawable = 10, texture = 0 } },
    },
})
```

Notes:
- For metadata images, use names without `.png` (example: `image = 'shirt'`).
- Item labels and images can be generic while metadata carries the exact outfit values.

## 4bit Appearance Auto Grants

`Config.AppearanceItemGrant` controls automatic clothing-item grants after appearance save.

Common options:
- `enabled`
- `hooks` (`onConfirm` recommended)
- `captureDelayMs`
- `cooldownMs`
- `skipDefaults`
- `skipExisting`
- `bundleTorsoWithJackets`
- `includeTorsoItem`
- `components` and `props` slot mapping

Manual capture export:
```lua
exports['cvn-clothingitems']:grantCurrentAppearanceItems()
```

## Outfit Bag

`Config.OutfitBag` enables remote outfit changing from saved `4bit_appearance` outfits.

Flow:
1. Use `outfit_bag`.
2. Place physical bag prop.
3. Target bag and choose saved outfit.
4. Progress finishes, charge is consumed, outfit is applied.
5. Matching clothing metadata items are granted (duplicates skipped).

Important:
- Charge is consumed on successful outfit change.
- If outfit apply fails, charge is refunded.
- If no new items are added (duplicates/defaults), charge is still consumed because change succeeded.

## Donation Boxes And Trash Cans

`Config.ClothingItemStations` controls station zones.

Donation boxes:
- Named stash per configured box.
- Keeps contents for current runtime.
- Cleared when this resource starts.

Trash cans:
- Temporary stash per use.
- Cleared immediately when closed.

By default, stations allow clothing items from `Config.AppearanceItemGrant`.
Use `allowedItems = 'all'` to allow everything.

Example station config:
```lua
Config.ClothingItemStations = {
    enabled = true,
    allowedItems = 'clothing',
    donationBoxes = {
        {
            id = 'clothing_store_donation_1',
            label = 'Clothing Donation Box',
            coords = vec3(72.3, -1399.1, 29.4),
            radius = 0.8,
            slots = 40,
            weight = 80000,
        },
    },
    trashCans = {
        {
            id = 'clothing_store_trash_1',
            label = 'Clothing Trash Can',
            coords = vec3(73.8, -1398.6, 29.4),
            radius = 0.8,
            slots = 20,
            weight = 50000,
        },
    },
}
```

## Preset Clothing Sets

`Config.ClothingPresets` stores named preset clothing sets.

Example preset config:
```lua
Config.ClothingPresets = {
    example_blue_uniform = {
        label = 'Example Blue Uniform',
        items = {
            {
                item = 'clothing_jacket',
                label = 'Blue Jacket',
                image = 'shirt',
                components = {
                    { component = 3, male = { drawable = 0, texture = 0 }, female = { drawable = 0, texture = 0 } },
                    { component = 11, male = { drawable = 544, texture = 0 }, female = { drawable = 588, texture = 0 } },
                },
            },
            {
                item = 'clothing_pants',
                label = 'Blue Pants',
                image = 'pants',
                components = {
                    { component = 4, male = { drawable = 202, texture = 0 }, female = { drawable = 217, texture = 0 } },
                },
            },
        },
    },
}
```

Use server export:
```lua
exports['cvn-clothingitems']:giveClothingSet(targetId, 'your_preset_key')
```

Admin command:
```text
/cvngiveclothingset <playerId> <presetKey>
```

## Admin Lookup Commands

These are variant lookup/admin utilities:
- `/cvnmodels`
- `/cvncategories <model>`
- `/cvncollections <model> <category>`
- `/cvnvariants <model> <category> [collection|all] [limit]`
- `/cvnreloadvariants`
- `/cvngiveclothingset <playerId> <presetKey>`

## Config Notes

`Config.Inventory`:
- `provider = 'ox'` is default.
- `updateEvent = 'ox_inventory:updateInventory'` default.
- `clothingSlots` can be empty (`{}`) if your inventory has no dedicated clothing slots.

`Config.Defaults`:
- Controls what gets restored when a clothing item is removed/toggled off.

`Config.Commands`:
- Admin access provider can be `auto`, `ace`, `qbox`, `qbcore`, or `esx`.

`Config.Variants`:
- Must point to valid `variantsMetadata.json` in your `4bit_appearance` resource.

## Glove Toggle Note

This resource no longer uses a custom `data/gloves.lua` mapping file.
Glove on/off behavior comes from clothing toggle definitions (for example `ox_inventory/data/clothing_toggles.lua`).