-- Copy these entries into ox_inventory/data/items.lua inside the main item table.
-- Do not add this file to fxmanifest.lua; it is a copy-paste snippet only.
-- These are generic base items. The exact clothing label, icon, drawable,
-- texture, and collection are set through item metadata when the item is given.

--[[

["clothing_jacket"] = {
    label = "Jacket",
    weight = 200,
    stack = false,
    consume = 0,
    client = {
        event = "cvn-clothingitems:client:use",
        image = "shirt.png",
    }
},

["clothing_pants"] = {
    label = "Pants",
    weight = 200,
    stack = false,
    consume = 0,
    client = {
        event = "cvn-clothingitems:client:use",
        image = "pants.png",
    }
},

["clothing_shoes"] = {
    label = "Shoes",
    weight = 200,
    stack = false,
    consume = 0,
    client = {
        event = "cvn-clothingitems:client:use",
        image = "shoes.png",
    }
},

["clothing_undershirt"] = {
    label = "Undershirt",
    weight = 200,
    stack = false,
    consume = 0,
    client = {
        event = "cvn-clothingitems:client:use",
        image = "tshirt.png",
    }
},

["clothing_torso"] = {
    label = "Torso",
    weight = 200,
    stack = false,
    consume = 0,
    client = {
        event = "cvn-clothingitems:client:use",
        image = "shirt.png",
    }
},

["clothing_vest"] = {
    label = "Vest",
    weight = 200,
    stack = false,
    consume = 0,
    client = {
        event = "cvn-clothingitems:client:use",
        image = "vest_normal.png",
    }
},

["clothing_mask"] = {
    label = "Mask",
    weight = 200,
    stack = false,
    consume = 0,
    client = {
        event = "cvn-clothingitems:client:use",
        image = "mask.png",
    }
},

["clothing_hat"] = {
    label = "Hat",
    weight = 200,
    stack = false,
    consume = 0,
    client = {
        event = "cvn-clothingitems:client:use",
        image = "hat.png",
    }
},

["clothing_glasses"] = {
    label = "Glasses",
    weight = 200,
    stack = false,
    consume = 0,
    client = {
        event = "cvn-clothingitems:client:use",
        image = "glasses.png",
    }
},

["clothing_ears"] = {
    label = "Ears",
    weight = 200,
    stack = false,
    consume = 0,
    client = {
        event = "cvn-clothingitems:client:use",
        image = "hat.png",
    }
},

["clothing_bag"] = {
    label = "Bag",
    weight = 200,
    stack = false,
    consume = 0,
    client = {
        event = "cvn-clothingitems:client:use",
        image = "bag.png",
    }
},

["clothing_accessory"] = {
    label = "Accessory",
    weight = 200,
    stack = false,
    consume = 0,
    client = {
        event = "cvn-clothingitems:client:use",
        image = "shirt.png",
    }
},

["clothing_watch"] = {
    label = "Watch",
    weight = 200,
    stack = false,
    consume = 0,
    client = {
        event = "cvn-clothingitems:client:use",
        image = "casio-watch.png",
    }
},

["clothing_bracelet"] = {
    label = "Bracelet",
    weight = 200,
    stack = false,
    consume = 0,
    client = {
        event = "cvn-clothingitems:client:use",
        image = "bracelet.png",
    }
},

["clothing_decal"] = {
    label = "Decal",
    weight = 200,
    stack = false,
    consume = 0,
    client = {
        event = "cvn-clothingitems:client:use",
        image = "shirt.png",
    }
},

["outfit_bag"] = {
    label = "Outfit Bag",
    weight = 1000,
    stack = false,
    consume = 0,
    client = {
        event = "cvn-clothingitems:client:useOutfitBag",
        image = "bag.png",
    }
},

["outfit_change_charge"] = {
    label = "Outfit Change Charge",
    weight = 200,
    stack = true,
    consume = 0,
    client = {
        event = "cvn-clothingitems:client:useOutfitCharge",
        image = "shirt.png",
    }
},


]]