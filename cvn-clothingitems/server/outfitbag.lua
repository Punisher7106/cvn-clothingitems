local outfitBags = {}
local pendingOutfitBagDrops = {}
local pendingOutfitBagChanges = {}

local function getOutfitBagConfig()
    return type(Config.OutfitBag) == 'table' and Config.OutfitBag or {}
end

local function notify(source, message)
    if source == 0 then
        print(('[cvn-clothingitems] %s'):format(message))
        return
    end

    TriggerClientEvent('chat:addMessage', source, {
        args = { 'CVN Clothing', message },
    })
end

local function getInventoryConfig()
    return type(Config.Inventory) == 'table' and Config.Inventory or {}
end

local function getItemCount(source, itemName)
    local inventoryConfig = getInventoryConfig()
    local provider = tostring(inventoryConfig.provider or 'ox'):lower()

    if provider == 'ox' then
        local ok, count = pcall(function()
            return exports.ox_inventory:Search(source, 'count', itemName)
        end)

        if ok then
            return tonumber(count) or 0
        end
    end

    return 0
end

local function removeInventoryItem(source, itemName, count, metadata, slot)
    local inventoryConfig = getInventoryConfig()
    local provider = tostring(inventoryConfig.provider or 'ox'):lower()

    if provider ~= 'ox' then
        return false, ('Inventory provider %s needs an outfit bag adapter.'):format(provider)
    end

    local ok, success, response = pcall(function()
        return exports.ox_inventory:RemoveItem(source, itemName, count, metadata, slot)
    end)

    if not ok then
        return false, success
    end

    return success == true, response
end

local function addInventoryItem(source, itemName, count, metadata)
    local inventoryConfig = getInventoryConfig()
    local provider = tostring(inventoryConfig.provider or 'ox'):lower()

    if provider ~= 'ox' then
        return false, ('Inventory provider %s needs an outfit bag adapter.'):format(provider)
    end

    local ok, success, response = pcall(function()
        return exports.ox_inventory:AddItem(source, itemName, count, metadata)
    end)

    if not ok then
        return false, success
    end

    return success == true, response
end

local function getSlotItem(source, slot)
    slot = tonumber(slot)
    if not slot then return nil end

    local inventoryConfig = getInventoryConfig()
    local provider = tostring(inventoryConfig.provider or 'ox'):lower()

    if provider ~= 'ox' then return nil end

    local ok, item = pcall(function()
        return exports.ox_inventory:GetSlot(source, slot)
    end)

    if ok and type(item) == 'table' then
        return item
    end

    return nil
end

local function createEvidenceAt(coords, evidenceType, metadata)
    local outfitConfig = getOutfitBagConfig()
    local evidence = type(outfitConfig.evidence) == 'table' and outfitConfig.evidence or {}

    if evidence.enabled ~= true then return end

    local resource = evidence.resource or 'p_policejob'
    if GetResourceState(resource) ~= 'started' then return end

    pcall(function()
        exports[resource]:createEvidence(evidenceType, coords, metadata or {})
    end)
end

local function getBagData(source, netId, coords)
    local bag = outfitBags[netId]
    local resolvedNetId = netId

    if not bag and type(coords) == 'vector3' then
        local closestDistance

        for bagNetId, bagData in pairs(outfitBags) do
            if bagData.owner == source and type(bagData.coords) == 'vector3' then
                local distance = #(bagData.coords - coords)

                if not closestDistance or distance < closestDistance then
                    closestDistance = distance
                    resolvedNetId = bagNetId
                    bag = bagData
                end
            end
        end

        local outfitConfig = getOutfitBagConfig()
        if closestDistance and closestDistance > ((outfitConfig.useDistance or 2.2) + 1.0) then
            bag = nil
            resolvedNetId = netId
        end
    end

    if not bag then return nil, 'Bag not found.' end
    if bag.owner ~= source then return nil, 'Only the owner can use this bag.' end

    return bag, nil, resolvedNetId
end

local function playerNearCoords(source, coords, maxDistance)
    if type(coords) ~= 'vector3' then return false end

    local ped = GetPlayerPed(source)
    if ped == 0 then return false end

    return #(GetEntityCoords(ped) - coords) <= maxDistance
end

local function hasOutfitCharge(source)
    local outfitConfig = getOutfitBagConfig()
    if outfitConfig.requireChargeItem ~= true then return true end

    return getItemCount(source, outfitConfig.chargeItem or 'outfit_change_charge') > 0
end

local function consumeOutfitCharge(source)
    local outfitConfig = getOutfitBagConfig()
    if outfitConfig.requireChargeItem ~= true or outfitConfig.consumeChargeOnChange == false then
        return true
    end

    local chargeItem = outfitConfig.chargeItem or 'outfit_change_charge'
    if getItemCount(source, chargeItem) <= 0 then
        return false
    end

    local success = removeInventoryItem(source, chargeItem, 1)
    return success == true
end

local function refundOutfitCharge(source)
    local outfitConfig = getOutfitBagConfig()
    if outfitConfig.requireChargeItem ~= true or outfitConfig.consumeChargeOnChange == false then
        return
    end

    addInventoryItem(source, outfitConfig.chargeItem or 'outfit_change_charge', 1)
end

local function createDropToken(source)
    return ('%s:%s:%s'):format(source, os.time(), math.random(100000, 999999))
end

RegisterNetEvent('cvn-clothingitems:server:dropOutfitBag', function(slot)
    local src = source
    local outfitConfig = getOutfitBagConfig()
    if outfitConfig.enabled ~= true then return end

    local target = type(outfitConfig.target) == 'table' and outfitConfig.target or {}
    local targetResource = target.resource or 'ox_target'
    if GetResourceState(targetResource) ~= 'started' then
        notify(src, 'Outfit bags require ox_target to be started.')
        return
    end

    local itemName = outfitConfig.item or 'outfit_bag'
    local slotItem = getSlotItem(src, slot)

    if not slotItem or slotItem.name ~= itemName then
        notify(src, 'Could not find that outfit bag item.')
        return
    end

    local removed, response = removeInventoryItem(src, itemName, 1, nil, slotItem.slot)
    if not removed then
        notify(src, ('Could not place outfit bag: %s'):format(tostring(response)))
        return
    end

    local token = createDropToken(src)

    pendingOutfitBagDrops[token] = {
        owner = src,
        itemName = itemName,
        metadata = slotItem.metadata or {},
    }

    TriggerClientEvent('cvn-clothingitems:client:createOutfitBag', src, token)

    SetTimeout(10000, function()
        local pending = pendingOutfitBagDrops[token]
        if not pending then return end

        pendingOutfitBagDrops[token] = nil
        addInventoryItem(pending.owner, pending.itemName, 1, pending.metadata)
        notify(pending.owner, 'Could not place outfit bag.')
    end)
end)

RegisterNetEvent('cvn-clothingitems:server:registerOutfitBag', function(token, netId, coords)
    local src = source
    local pending = pendingOutfitBagDrops[token]
    if not pending or pending.owner ~= src then return end

    netId = tonumber(netId)
    if not netId or netId == 0 or type(coords) ~= 'vector3' then
        pendingOutfitBagDrops[token] = nil
        addInventoryItem(src, pending.itemName, 1, pending.metadata)
        notify(src, 'Could not register outfit bag.')
        return
    end

    pendingOutfitBagDrops[token] = nil

    outfitBags[netId] = {
        owner = src,
        metadata = pending.metadata or {},
        coords = coords,
    }

    TriggerClientEvent('cvn-clothingitems:client:spawnOutfitBag', -1, netId)

    local outfitConfig = getOutfitBagConfig()
    local evidence = type(outfitConfig.evidence) == 'table' and outfitConfig.evidence or {}
    createEvidenceAt(coords, evidence.touchType or 'bag_fingerprint', {
        player = ('src:%s'):format(src),
        type = 'bag_drop',
    })
end)

lib.callback.register('cvn-clothingitems:server:pickupOutfitBag', function(source, netId, coords)
    local outfitConfig = getOutfitBagConfig()
    if outfitConfig.enabled ~= true then return false, 'Outfit bags are disabled.' end

    netId = tonumber(netId)
    local bag, message, resolvedNetId = getBagData(source, netId, coords)
    if not bag then return false, message end
    netId = resolvedNetId or netId

    local bagCoords = bag.coords or coords
    if not playerNearCoords(source, bagCoords, outfitConfig.useDistance or 2.2) then
        return false, 'Get closer to the bag.'
    end

    local itemName = outfitConfig.item or 'outfit_bag'
    local success, response = addInventoryItem(source, itemName, 1, bag.metadata or {})
    if not success then
        return false, ('Could not pick up outfit bag: %s'):format(tostring(response))
    end

    TriggerClientEvent('cvn-clothingitems:client:despawnOutfitBag', -1, netId)

    outfitBags[netId] = nil

    return true, 'Picked up outfit bag.'
end)

lib.callback.register('cvn-clothingitems:server:openOutfitBag', function(source, netId, coords)
    local outfitConfig = getOutfitBagConfig()
    if outfitConfig.enabled ~= true then return false, 'Outfit bags are disabled.' end

    netId = tonumber(netId)
    local bag, message, resolvedNetId = getBagData(source, netId, coords)
    if not bag then return false, message end
    netId = resolvedNetId or netId

    local bagCoords = bag.coords or coords
    if not playerNearCoords(source, bagCoords, outfitConfig.useDistance or 2.2) then
        return false, 'Get closer to the bag.'
    end

    if not hasOutfitCharge(source) then
        return false, ('You need an %s.'):format(outfitConfig.chargeItem or 'outfit_change_charge')
    end

    local appearance = type(outfitConfig.appearance) == 'table' and outfitConfig.appearance or {}
    local resource = appearance.resource or '4bit_appearance'
    if GetResourceState(resource) ~= 'started' then
        return false, 'Appearance resource is not started.'
    end

    local ok, outfits = pcall(function()
        return exports[resource]:getPlayerOutfits(source, appearance.outfitType or 'personal')
    end)

    if not ok or type(outfits) ~= 'table' then
        return false, 'Could not read saved outfits.'
    end

    TriggerClientEvent('cvn-clothingitems:client:chooseOutfitBagOutfit', source, outfits, netId)
    return true
end)

RegisterNetEvent('cvn-clothingitems:server:cancelOutfitBagChange', function(netId)
end)

lib.callback.register('cvn-clothingitems:server:consumeOutfitBagCharge', function(source, netId, outfitId)
    local outfitConfig = getOutfitBagConfig()
    if outfitConfig.enabled ~= true then return false, 'Outfit bags are disabled.' end

    netId = tonumber(netId)
    local bag, message = getBagData(source, netId)
    if not bag then return false, message end

    local bagCoords = bag.coords
    if not playerNearCoords(source, bagCoords, outfitConfig.useDistance or 2.2) then
        return false, 'Get closer to the bag.'
    end

    if not consumeOutfitCharge(source) then
        return false, ('You need an %s.'):format(outfitConfig.chargeItem or 'outfit_change_charge')
    end

    pendingOutfitBagChanges[source] = {
        netId = netId,
        outfitId = outfitId,
        time = os.time(),
    }

    return true
end)

RegisterNetEvent('cvn-clothingitems:server:finishOutfitBagChange', function(netId, outfitId)
    local src = source
    local outfitConfig = getOutfitBagConfig()
    if outfitConfig.enabled ~= true then return end

    netId = tonumber(netId)
    local pending = pendingOutfitBagChanges[src]
    if not pending or pending.netId ~= netId or pending.outfitId ~= outfitId then return end

    pendingOutfitBagChanges[src] = nil

    local ped = GetPlayerPed(src)
    local coords = ped ~= 0 and GetEntityCoords(ped) or nil
    local evidence = type(outfitConfig.evidence) == 'table' and outfitConfig.evidence or {}

    if coords then
        createEvidenceAt(coords, evidence.changeType or 'clothing_fibers', {
            player = ('src:%s'):format(src),
            outfit = outfitId,
        })
    end
end)

RegisterNetEvent('cvn-clothingitems:server:failOutfitBagChange', function(netId, outfitId)
    local src = source

    netId = tonumber(netId)
    local pending = pendingOutfitBagChanges[src]
    if not pending or pending.netId ~= netId or pending.outfitId ~= outfitId then return end

    pendingOutfitBagChanges[src] = nil
    refundOutfitCharge(src)
end)

AddEventHandler('playerDropped', function()
    local src = source
    pendingOutfitBagChanges[src] = nil

    for token, pending in pairs(pendingOutfitBagDrops) do
        if pending.owner == src then
            pendingOutfitBagDrops[token] = nil
        end
    end

    for netId, bag in pairs(outfitBags) do
        if bag.owner == src then
            TriggerClientEvent('cvn-clothingitems:client:despawnOutfitBag', -1, netId)

            outfitBags[netId] = nil
        end
    end
end)
