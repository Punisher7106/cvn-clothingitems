Config = {}

Config.ItemUseEvent = 'cvn-clothingitems:client:use'

Config.Variants = {
    resource = '4bit_appearance',
    file = 'public/shared/variantsMetadata.json',
    cacheMs = 60000,
}

Config.Commands = {
    adminOnly = true,
    ace = 'group.admin',
    adminProvider = 'auto', -- auto | ace | qbox | qbcore | esx
    allowAceFallback = true,
    qboxGroups = { 'admin', 'god' },
    qbcorePermissions = { 'admin', 'god' },
    esxGroups = { 'admin', 'superadmin' },
    previewLimit = 20,
}

Config.Inventory = {
    provider = 'ox', -- ox | custom
    updateEvent = 'ox_inventory:updateInventory',
    clothingSlots = {
    --[[       
        [36] = { kind = 'prop', id = 0 }, -- hat
        [37] = { kind = 'prop', id = 1 }, -- glasses
        [38] = { kind = 'component', id = 1 }, -- mask
        [39] = { kind = 'prop', id = 2 }, -- ears
        [40] = { kind = 'prop', id = 6 }, -- watch
        [41] = { kind = 'prop', id = 7 }, -- bracelet
        [42] = { kind = 'component', id = 7 }, -- accessory
        [43] = { kind = 'component', id = 11 }, -- jacket
        [44] = { kind = 'component', id = 3 }, -- gloves/arms
        [45] = { kind = 'component', id = 8 }, -- undershirt
        [46] = { kind = 'component', id = 9 }, -- vest
        [47] = { kind = 'component', id = 4 }, -- pants
        [48] = { kind = 'component', id = 6 }, -- shoes
        [49] = { kind = 'component', id = 5 }, -- bag
        [50] = { kind = 'component', id = 10 }, -- decal
    ]]
    }, -- keep empty if your inventory does not use dedicated clothing slots
    custom = {
        -- Optional custom hooks for non-ox inventory systems.
        -- Set these to functions in your own setup if needed.
        getItemData = false, -- function(itemName) -> itemData table
        addItem = false, -- server only: function(target, itemName, count, metadata) -> success, response
        findItems = false, -- server only: function(target, itemName) -> item slot table/list for duplicate checks
        parseInventoryChange = false, -- function(slotKey, entry, changes) -> { slot = number, entry = table|false, removed = boolean }
    },
}

Config.AppearanceItemGrant = {
    enabled = true,
    resource = '4bit_appearance',
    hooks = { 'onConfirm' }, -- use onConfirm so cancel/escape does not give clothing
    captureDelayMs = 750,
    cooldownMs = 10000,
    notify = true,
    allowUnknownShop = true, -- keep this true if hook data does not include shop type
    allowedShopTypes = {
        ['4bit_clothing'] = true,
        clothing = true,
    },
    skipDefaults = true,
    skipExisting = true,
    bundleTorsoWithJackets = true,
    includeTorsoItem = false,
    includeDrawableInLabel = true,
    components = {
        { feature = 'mask', component = 1, item = 'clothing_mask', label = 'Mask', image = 'mask' },
        { feature = 'torsos', component = 3, item = 'clothing_torso', label = 'Torso', image = 'shirt' },
        { feature = 'legs', component = 4, item = 'clothing_pants', label = 'Pants', image = 'pants' },
        { feature = 'bags', component = 5, item = 'clothing_bag', label = 'Bag', image = 'bag' },
        { feature = 'shoes', component = 6, item = 'clothing_shoes', label = 'Shoes', image = 'shoes' },
        { feature = 'accessories', component = 7, item = 'clothing_accessory', label = 'Accessory', image = 'shirt' },
        { feature = 'undershirts', component = 8, item = 'clothing_undershirt', label = 'Undershirt', image = 'tshirt' },
        { feature = 'vests', component = 9, item = 'clothing_vest', label = 'Vest', image = 'vest_normal' },
        { feature = 'decals', component = 10, item = 'clothing_decal', label = 'Decal', image = 'shirt' },
        { feature = 'jackets', component = 11, item = 'clothing_jacket', label = 'Jacket', image = 'shirt' },
    },
    props = {
        { feature = 'hat', prop = 0, item = 'clothing_hat', label = 'Hat', image = 'hat' },
        { feature = 'glasses', prop = 1, item = 'clothing_glasses', label = 'Glasses', image = 'glasses' },
        { feature = 'ears', prop = 2, item = 'clothing_ears', label = 'Ears', image = 'hat' },
        { feature = 'watches', prop = 6, item = 'clothing_watch', label = 'Watch', image = 'casio-watch' },
        { feature = 'bracelets', prop = 7, item = 'clothing_bracelet', label = 'Bracelet', image = 'bracelet' },
    },
}

Config.OutfitBag = {
    enabled = true,
    item = 'outfit_bag',
    chargeItem = 'outfit_change_charge',
    requireChargeItem = true,
    consumeChargeOnChange = true,
    grantClothingItems = true,
    grantClothingItemsDelayMs = 750,
    useDistance = 2.2,
    changeDelayMs = 45000,
    despawnOnPickup = true,
    bagModel = `prop_cs_heist_bag_02`,
    target = {
        resource = 'ox_target',
        useModelTarget = true,
        registerTimeoutMs = 5000,
        changeIcon = 'fa-solid fa-shirt',
        pickupIcon = 'fa-solid fa-hand',
    },
    appearance = {
        resource = '4bit_appearance',
        outfitType = 'personal',
    },
    evidence = {
        enabled = true,
        resource = 'p_policejob',
        touchType = 'bag_fingerprint',
        changeType = 'clothing_fibers',
    },
}

Config.ClothingItemStations = {
    enabled = true,
    inventoryResource = 'ox_inventory',
    targetResource = 'ox_target',
    debug = false,
    defaultSlots = 30,
    defaultWeight = 50000,
    defaultDistance = 2.0,
    defaultRadius = 0.8,
    allowedItems = 'clothing', -- clothing | all | { clothing_jacket = true, clothing_hat = true }
    additionalAllowedItems = {},
    donationBoxes = {
        -- Example:
        -- {
        --     id = 'clothing_store_donation_1',
        --     label = 'Clothing Donation Box',
        --     coords = vec3(72.3, -1399.1, 29.4),
        --     radius = 0.8,
        --     slots = 40,
        --     weight = 80000,
        -- },
    },
    trashCans = {
        -- Example:
        -- {
        --     id = 'clothing_store_trash_1',
        --     label = 'Clothing Trash Can',
        --     coords = vec3(73.8, -1398.6, 29.4),
        --     radius = 0.8,
        --     slots = 20,
        --     weight = 50000,
        -- },
    },
}

-- You can rename keys freely and give with:
-- exports['cvn-clothingitems']:giveClothingSet(targetId, 'your_preset_key')
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
            {
                item = 'clothing_shoes',
                label = 'Black Shoes',
                image = 'shoes',
                components = {
                    { component = 6, male = { drawable = 113, texture = 0 }, female = { drawable = 117, texture = 0 } },
                },
            },
        },
    },
    example_red_uniform = {
        label = 'Example Red Uniform',
        items = {
            {
                item = 'clothing_jacket',
                label = 'Red Jacket',
                image = 'shirt',
                components = {
                    { component = 3, male = { drawable = 0, texture = 0 }, female = { drawable = 0, texture = 0 } },
                    { component = 11, male = { drawable = 544, texture = 1 }, female = { drawable = 588, texture = 1 } },
                },
            },
            {
                item = 'clothing_pants',
                label = 'Red Pants',
                image = 'pants',
                components = {
                    { component = 4, male = { drawable = 202, texture = 1 }, female = { drawable = 217, texture = 1 } },
                },
            },
            {
                item = 'clothing_shoes',
                label = 'Black Shoes',
                image = 'shoes',
                components = {
                    { component = 6, male = { drawable = 113, texture = 0 }, female = { drawable = 117, texture = 0 } },
                },
            },
        },
    },
}

Config.FallbackDefaults = {
    component = { drawable = 0, texture = 0, collection = '' },
    prop = { drawable = -1, texture = 0, collection = '' },
}

Config.Defaults = {
    male = {
        components = {
            [1] = { drawable = 0, texture = 0 },
            [3] = { drawable = 15, texture = 0 },
            [4] = { drawable = 61, texture = 'random' },
            [5] = { drawable = 0, texture = 0 },
            [6] = { drawable = 34, texture = 0 },
            [8] = { drawable = 15, texture = 0 },
            [9] = { drawable = 0, texture = 0 },
            [11] = { drawable = 15, texture = 'random' },
        },
        props = {
            [0] = { drawable = -1, texture = 0 },
            [1] = { drawable = -1, texture = 0 },
            [2] = { drawable = -1, texture = 0 },
            [6] = { drawable = -1, texture = 0 },
            [7] = { drawable = -1, texture = 0 },
        },
    },
    female = {
        components = {
            [1] = { drawable = 0, texture = 0 },
            [3] = { drawable = 15, texture = 0 },
            [4] = { drawable = 17, texture = 'random' },
            [5] = { drawable = 0, texture = 0 },
            [6] = { drawable = 35, texture = 0 },
            [8] = { drawable = 2, texture = 0 },
            [9] = { drawable = 0, texture = 0 },
            [11] = { drawable = 5, texture = 'random' },
        },
        props = {
            [0] = { drawable = -1, texture = 0 },
            [1] = { drawable = -1, texture = 0 },
            [2] = { drawable = -1, texture = 0 },
            [6] = { drawable = -1, texture = 0 },
            [7] = { drawable = -1, texture = 0 },
        },
    },
}
