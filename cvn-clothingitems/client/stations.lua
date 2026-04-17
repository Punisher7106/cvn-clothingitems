if not lib then return end

local stationZones = {}

local function getStationConfig()
    return type(Config.ClothingItemStations) == 'table' and Config.ClothingItemStations or {}
end

local function notify(message, notifyType)
    if lib and lib.notify then
        lib.notify({
            description = message,
            type = notifyType or 'inform',
        })
        return
    end

    print(('[cvn-clothingitems] %s'):format(message))
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

local function toVector3Size(value)
    if type(value) == 'vector3' then return value end
    if type(value) ~= 'table' then return nil end

    local x = tonumber(value.x or value[1])
    local y = tonumber(value.y or value[2])
    local z = tonumber(value.z or value[3])

    if not x or not y or not z then return nil end
    return vector3(x, y, z)
end

local function waitForResource(resource)
    while GetResourceState(resource) ~= 'started' do
        Wait(1000)
    end
end

local function openStation(stationType, stationId)
    local callbackName = stationType == 'trash'
        and 'cvn-clothingitems:server:createTrashStash'
        or 'cvn-clothingitems:server:getDonationBoxStash'

    local ok, stashId, message = lib.callback.await(callbackName, false, stationId)

    if not ok or not stashId then
        notify(message or 'Could not open clothing station.', 'error')
        return
    end

    local inventoryResource = getStationConfig().inventoryResource or 'ox_inventory'
    local opened = exports[inventoryResource]:openInventory('stash', stashId)

    if opened == false then
        notify('Could not open clothing station inventory.', 'error')
    end
end

local function addStationZone(targetResource, stationType, station, index)
    if type(station) ~= 'table' or station.enabled == false then return end

    local stationConfig = getStationConfig()
    local coords = toVector3(station.coords)
    if not coords then return end

    local prefix = stationType == 'trash' and 'trash' or 'donation'
    local stationId = sanitizeStationId(station.id, prefix, index)
    local zoneName = ('cvn_clothingitems_%s_%s'):format(prefix, stationId)
    local label = station.targetLabel or station.label or (stationType == 'trash' and 'Discard Clothing' or 'Open Donation Box')
    local icon = station.icon or (stationType == 'trash' and 'fa-solid fa-trash-can' or 'fa-solid fa-box-open')
    local distance = station.distance or stationConfig.defaultDistance or 2.0

    local options = {
        {
            name = zoneName,
            icon = icon,
            label = label,
            distance = distance,
            onSelect = function()
                openStation(stationType, stationId)
            end,
        },
    }

    local size = toVector3Size(station.size)
    local zoneId

    if size then
        zoneId = exports[targetResource]:addBoxZone({
            name = zoneName,
            coords = coords,
            size = size,
            rotation = station.rotation or 0.0,
            debug = station.debug == true or stationConfig.debug == true,
            options = options,
        })
    else
        zoneId = exports[targetResource]:addSphereZone({
            name = zoneName,
            coords = coords,
            radius = station.radius or stationConfig.defaultRadius or 0.8,
            debug = station.debug == true or stationConfig.debug == true,
            options = options,
        })
    end

    stationZones[#stationZones + 1] = zoneId or zoneName
end

local function registerStationZones()
    local stationConfig = getStationConfig()
    if stationConfig.enabled ~= true then return end

    local targetResource = stationConfig.targetResource or 'ox_target'
    local inventoryResource = stationConfig.inventoryResource or 'ox_inventory'

    waitForResource(targetResource)
    waitForResource(inventoryResource)

    for i = 1, #(stationConfig.donationBoxes or {}) do
        addStationZone(targetResource, 'donation', stationConfig.donationBoxes[i], i)
    end

    for i = 1, #(stationConfig.trashCans or {}) do
        addStationZone(targetResource, 'trash', stationConfig.trashCans[i], i)
    end
end

CreateThread(registerStationZones)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    local targetResource = getStationConfig().targetResource or 'ox_target'
    if GetResourceState(targetResource) ~= 'started' then return end

    for i = 1, #stationZones do
        pcall(function()
            exports[targetResource]:removeZone(stationZones[i])
        end)
    end
end)
