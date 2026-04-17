local donationBoxes = {}
local donationStashes = {}
local trashStashes = {}
local hooksRegistered = false

local function getRootConfig()
    local cfg = rawget(_G, 'Config')
    if type(cfg) == 'table' then
        return cfg
    end

    return {}
end

local function getStationConfig()
    local cfg = getRootConfig()
    return type(cfg.ClothingItemStations) == 'table' and cfg.ClothingItemStations or {}
end

local function notify(source, message)
    if source == 0 then
        print(('[cvn-clothingitems] %s'):format(message))
        return
    end

    TriggerClientEvent('chat:addMessage', source, {
        args = { 'CVN Clothing', message }
    })
end

local function sanitizeStationId(value, prefix, index)
    value = type(value) == 'string' and value or ('%s_%s'):format(prefix, index)
    value = value:lower():gsub('[^%w_%-]', '_')
    return value
end

local function toVector3(value)
    if type(value) == 'vector3' then return value end
    if type(value) ~= 'table' then return nil end

    local x = tonumber(value.x or value[1])
    local y = tonumber(value.y or value[2])
    local z = tonumber(value.z or value[3])

    if not x or not y or not z then return nil end
    return vector3(x, y, z)
end

local function getStationSlots(station)
    return tonumber(station.slots) or tonumber(getStationConfig().defaultSlots) or 30
end

local function getStationWeight(station)
    return tonumber(station.weight or station.maxWeight) or tonumber(getStationConfig().defaultWeight) or 50000
end

local function getStationDistance(station)
    return tonumber(station.distance) or tonumber(getStationConfig().defaultDistance) or 2.0
end

local function getInventoryResource()
    return getStationConfig().inventoryResource or 'ox_inventory'
end

local function waitForInventory()
    local inventoryResource = getInventoryResource()

    while GetResourceState(inventoryResource) ~= 'started' do
        Wait(1000)
    end

    return inventoryResource
end

local function playerNearStation(source, station)
    local coords = station and station.coords
    if type(coords) ~= 'vector3' then return false end

    local ped = GetPlayerPed(source)
    if ped == 0 then return false end

    return #(GetEntityCoords(ped) - coords) <= (getStationDistance(station) + 1.0)
end

local function createTemporaryStash(station, prefix)
    local inventoryResource = getInventoryResource()
    local ok, stashId = pcall(function()
        return exports[inventoryResource]:CreateTemporaryStash({
            label = station.label or (prefix == 'trash' and 'Clothing Trash' or 'Clothing Donation Box'),
            slots = getStationSlots(station),
            maxWeight = getStationWeight(station),
            owner = false,
            coords = station.coords,
            items = {},
        })
    end)

    if not ok or type(stashId) ~= 'string' then
        return nil
    end

    return stashId
end

local function registerDonationStash(stationId, station)
    local inventoryResource = getInventoryResource()
    local stashId = ('cvn_clothingitems_donation_%s'):format(stationId)

    local ok = pcall(function()
        exports[inventoryResource]:RegisterStash(
            stashId,
            station.label or 'Clothing Donation Box',
            getStationSlots(station),
            getStationWeight(station),
            false,
            nil,
            station.coords
        )

        exports[inventoryResource]:ClearInventory(stashId, false)
    end)

    if not ok then return nil end
    return stashId
end

local function getClothingItemNames()
    local items = {}
    local cfg = getRootConfig()
    local grantConfig = type(cfg.AppearanceItemGrant) == 'table' and cfg.AppearanceItemGrant or {}

    for i = 1, #(grantConfig.components or {}) do
        local item = grantConfig.components[i] and grantConfig.components[i].item
        if type(item) == 'string' and item ~= '' then
            items[item] = true
        end
    end

    for i = 1, #(grantConfig.props or {}) do
        local item = grantConfig.props[i] and grantConfig.props[i].item
        if type(item) == 'string' and item ~= '' then
            items[item] = true
        end
    end

    local stationConfig = getStationConfig()
    for key, value in pairs(stationConfig.additionalAllowedItems or {}) do
        if type(key) == 'string' and value == true then
            items[key] = true
        elseif type(value) == 'string' and value ~= '' then
            items[value] = true
        end
    end

    return items
end

local function normalizeAllowedItems(value)
    if value == nil then
        value = getStationConfig().allowedItems
    end

    if value == nil or value == 'clothing' then
        return getClothingItemNames()
    end

    if value == 'all' or value == false then
        return false
    end

    if type(value) ~= 'table' then
        return getClothingItemNames()
    end

    local allowed = {}

    for key, item in pairs(value) do
        if type(key) == 'string' and item == true then
            allowed[key] = true
        elseif type(item) == 'string' and item ~= '' then
            allowed[item] = true
        end
    end

    return allowed
end

local function isItemAllowed(station, itemName)
    local allowed = station.allowedItemsCache
    if allowed == nil then
        allowed = normalizeAllowedItems(station.allowedItems)
        station.allowedItemsCache = allowed
    end

    return allowed == false or allowed[itemName] == true
end

local function registerDonationBoxes()
    local stationConfig = getStationConfig()
    if stationConfig.enabled ~= true then return end

    waitForInventory()

    donationBoxes = {}
    donationStashes = {}

    for i = 1, #(stationConfig.donationBoxes or {}) do
        local station = stationConfig.donationBoxes[i]

        if type(station) == 'table' and station.enabled ~= false then
            local coords = toVector3(station.coords)

            if coords then
                local stationId = sanitizeStationId(station.id, 'donation', i)
                local stationData = {
                    id = stationId,
                    label = station.label,
                    coords = coords,
                    slots = station.slots,
                    weight = station.weight,
                    maxWeight = station.maxWeight,
                    distance = station.distance,
                    allowedItems = station.allowedItems,
                }

                local stashId = registerDonationStash(stationId, stationData)
                if stashId then
                    stationData.stashId = stashId
                    donationBoxes[stationId] = stationData
                    donationStashes[stashId] = stationData
                else
                    print(('[cvn-clothingitems] Failed to create donation box stash: %s'):format(stationId))
                end
            end
        end
    end
end

local function registerStationHooks()
    if hooksRegistered then return end

    local inventoryResource = waitForInventory()
    hooksRegistered = true

    exports[inventoryResource]:registerHook('swapItems', function(payload)
        local toStation = donationStashes[tostring(payload.toInventory)] or trashStashes[tostring(payload.toInventory)]
        if not toStation then return end

        local itemName = payload.fromSlot and payload.fromSlot.name
        if not itemName or isItemAllowed(toStation, itemName) then return end

        notify(payload.source, 'Only clothing items can be placed here.')
        return false
    end)
end

lib.callback.register('cvn-clothingitems:server:getDonationBoxStash', function(source, stationId)
    local stationConfig = getStationConfig()
    if stationConfig.enabled ~= true then return false, nil, 'Clothing stations are disabled.' end

    stationId = sanitizeStationId(stationId, 'donation', 0)
    local station = donationBoxes[stationId]

    if not station then return false, nil, 'Donation box not found.' end
    if not playerNearStation(source, station) then return false, nil, 'Get closer to the donation box.' end

    return true, station.stashId
end)

lib.callback.register('cvn-clothingitems:server:createTrashStash', function(source, stationId)
    local stationConfig = getStationConfig()
    if stationConfig.enabled ~= true then return false, nil, 'Clothing stations are disabled.' end

    stationId = sanitizeStationId(stationId, 'trash', 0)
    local configuredStation

    for i = 1, #(stationConfig.trashCans or {}) do
        local station = stationConfig.trashCans[i]
        local id = type(station) == 'table' and sanitizeStationId(station.id, 'trash', i)

        if id == stationId and station.enabled ~= false then
            configuredStation = station
            break
        end
    end

    if not configuredStation then return false, nil, 'Trash can not found.' end

    local station = {
        id = stationId,
        label = configuredStation.label,
        coords = toVector3(configuredStation.coords),
        slots = configuredStation.slots,
        weight = configuredStation.weight,
        maxWeight = configuredStation.maxWeight,
        distance = configuredStation.distance,
        allowedItems = configuredStation.allowedItems,
    }

    if not station.coords then return false, nil, 'Trash can is missing coords.' end
    if not playerNearStation(source, station) then return false, nil, 'Get closer to the trash can.' end

    local stashId = createTemporaryStash(station, 'trash')
    if not stashId then return false, nil, 'Could not create trash inventory.' end

    station.stashId = stashId
    trashStashes[stashId] = station

    return true, stashId
end)

AddEventHandler('ox_inventory:closedInventory', function(source, inventoryId)
    inventoryId = tostring(inventoryId)
    if not trashStashes[inventoryId] then return end

    local inventoryResource = getInventoryResource()
    pcall(function()
        exports[inventoryResource]:ClearInventory(inventoryId, false)
    end)

    trashStashes[inventoryId] = nil
end)

CreateThread(function()
    registerStationHooks()
    registerDonationBoxes()
end)

AddEventHandler('onResourceStart', function(resource)
    if resource == getInventoryResource() then
        hooksRegistered = false

        CreateThread(function()
            registerStationHooks()
            registerDonationBoxes()
        end)
    end
end)
