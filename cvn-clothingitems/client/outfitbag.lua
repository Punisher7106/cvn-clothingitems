local outfitBagTargets = {}

local componentToFeatureId = {
    [1] = 'mask',
    [2] = 'hair',
    [3] = 'torsos',
    [4] = 'legs',
    [5] = 'bags',
    [6] = 'shoes',
    [7] = 'accessories',
    [8] = 'undershirts',
    [9] = 'vests',
    [10] = 'decals',
    [11] = 'jackets',
}

local propToFeatureId = {
    [0] = 'hat',
    [1] = 'glasses',
    [2] = 'ears',
    [6] = 'watches',
    [7] = 'bracelets',
}

local function getOutfitBagConfig()
    return type(Config.OutfitBag) == 'table' and Config.OutfitBag or {}
end

local function getAppearanceGrantConfig()
    return type(Config.AppearanceItemGrant) == 'table' and Config.AppearanceItemGrant or {}
end

local function getPedGender(ped)
    return GetEntityModel(ped) == `mp_f_freemode_01` and 'female' or 'male'
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

local function getAppearanceResource()
    local outfitConfig = getOutfitBagConfig()
    local appearance = type(outfitConfig.appearance) == 'table' and outfitConfig.appearance or {}
    return appearance.resource or '4bit_appearance'
end

local function getTargetResource()
    local outfitConfig = getOutfitBagConfig()
    local target = type(outfitConfig.target) == 'table' and outfitConfig.target or {}
    return target.resource or 'ox_target'
end

local function requestModel(model, timeoutMs)
    if not IsModelInCdimage(model) then return false end

    RequestModel(model)

    local expires = GetGameTimer() + (timeoutMs or 5000)
    while not HasModelLoaded(model) and GetGameTimer() < expires do
        Wait(50)
    end

    return HasModelLoaded(model)
end

local function getNetworkEntity(netId, timeoutMs)
    local expires = GetGameTimer() + (timeoutMs or 5000)

    while GetGameTimer() < expires do
        if NetworkDoesNetworkIdExist(netId) then
            local entity = NetworkGetEntityFromNetworkId(netId)

            if entity and entity ~= 0 and DoesEntityExist(entity) then
                return entity
            end
        end

        Wait(100)
    end

    return nil
end

local function deleteNetworkEntity(netId)
    local entity = getNetworkEntity(netId, 2500)
    if not entity then return end

    NetworkRequestControlOfEntity(entity)

    local expires = GetGameTimer() + 1000
    while not NetworkHasControlOfEntity(entity) and GetGameTimer() < expires do
        Wait(50)
        NetworkRequestControlOfEntity(entity)
    end

    if DoesEntityExist(entity) then
        DeleteEntity(entity)
    end
end

local function applyOutfit(outfit)
    local appearanceResource = getAppearanceResource()
    if GetResourceState(appearanceResource) ~= 'started' then
        return false
    end

    if not outfit or type(outfit.appearance) ~= 'table' then
        return false
    end

    local ok, success = pcall(function()
        return exports[appearanceResource]:setPlayerAppearance(outfit.appearance)
    end)

    return ok and success ~= false
end

local function getVariantValues(value)
    if type(value) ~= 'table' then return nil end

    if value.drawable == nil then
        if type(value.values) == 'table' then return getVariantValues(value.values) end
        if type(value.value) == 'table' then return getVariantValues(value.value) end
        if type(value.data) == 'table' then return getVariantValues(value.data) end
    end

    local drawable = value.drawable
    if drawable == nil then drawable = value.drawableId end
    if drawable == nil then drawable = value.drawableid end
    if drawable == nil then drawable = value.drawable_id end
    if drawable == nil then drawable = value.drawableIndex end
    if drawable == nil then drawable = value.drawableindex end
    if drawable == nil then drawable = value[1] end

    drawable = tonumber(drawable)
    if drawable == nil then return nil end

    local texture = value.texture
    if texture == nil then texture = value.textureId end
    if texture == nil then texture = value.textureid end
    if texture == nil then texture = value.texture_id end
    if texture == nil then texture = value.textureIndex end
    if texture == nil then texture = value.textureindex end
    if texture == nil then texture = value[2] end

    local collection = value.collection
    if collection == nil then collection = value.collectionName end
    if collection == nil then collection = value.collection_name end
    if collection == nil then collection = value[3] end

    return {
        drawable = drawable,
        texture = tonumber(texture) or 0,
        collection = collection or '',
    }
end

local function setFeatureVariant(features, featureId, value)
    if type(featureId) ~= 'string' or featureId == '' then return end

    local variant = getVariantValues(value)
    if variant then
        features[featureId] = variant
    end
end

local function addComponentFeature(features, key, value)
    if type(key) == 'string' then
        local componentId = tonumber(key)
        setFeatureVariant(features, componentToFeatureId[componentId] or key, value)
        return
    end

    local componentId
    if type(value) == 'table' then
        componentId = value.component
            or value.componentId
            or value.componentid
            or value.component_id
            or value.id
    end

    componentId = tonumber(componentId or key)
    setFeatureVariant(features, componentToFeatureId[componentId], value)
end

local function addPropFeature(features, key, value)
    if type(key) == 'string' then
        local propId = tonumber(key)
        setFeatureVariant(features, propToFeatureId[propId] or key, value)
        return
    end

    local propId
    if type(value) == 'table' then
        propId = value.prop
            or value.propId
            or value.propid
            or value.prop_id
            or value.id
    end

    propId = tonumber(propId or key)
    setFeatureVariant(features, propToFeatureId[propId], value)
end

local function buildSavedOutfitFeatureMap(appearance)
    local features = {}
    if type(appearance) ~= 'table' then return features end

    if type(appearance.features) == 'table' then
        for _, feature in pairs(appearance.features) do
            if type(feature) == 'table' then
                local featureId = feature.id or feature.name or feature.feature
                setFeatureVariant(features, featureId, feature.values or feature.value or feature.data or feature)
            end
        end
    end

    if type(appearance.drawables) == 'table' then
        for key, value in pairs(appearance.drawables) do
            addComponentFeature(features, key, value)
        end
    end

    if type(appearance.components) == 'table' then
        for key, value in pairs(appearance.components) do
            addComponentFeature(features, key, value)
        end
    end

    if type(appearance.props) == 'table' then
        for key, value in pairs(appearance.props) do
            addPropFeature(features, key, value)
        end
    end

    return features
end

local function getComponentSnapshot(ped, featureMap, featureId, componentId)
    local variant = featureMap[featureId]
    if variant then return variant end

    return {
        drawable = GetPedDrawableVariation(ped, componentId),
        texture = GetPedTextureVariation(ped, componentId),
        collection = '',
    }
end

local function getPropSnapshot(ped, featureMap, featureId, propId)
    local variant = featureMap[featureId]
    if variant then return variant end

    return {
        drawable = GetPedPropIndex(ped, propId),
        texture = GetPedPropTextureIndex(ped, propId),
        collection = '',
    }
end

local function defaultMatchesVariant(defaultData, variant, isProp)
    if not defaultData or not variant then return false end

    local defaultDrawable = tonumber(defaultData.drawable)
    if defaultDrawable == nil or defaultDrawable ~= tonumber(variant.drawable) then
        return false
    end

    if isProp and defaultDrawable == -1 then
        return true
    end

    if defaultData.texture == 'random' or defaultData.randomTexture == true then
        return true
    end

    local defaultTexture = tonumber(defaultData.texture) or 0
    return defaultTexture == (tonumber(variant.texture) or 0)
end

local function shouldSkipComponentGrant(componentId, variant, gender)
    if not variant or tonumber(variant.drawable) == nil or tonumber(variant.drawable) < 0 then
        return true
    end

    local grantConfig = getAppearanceGrantConfig()
    if grantConfig.skipDefaults ~= true then return false end

    local defaults = Config.Defaults[gender] and Config.Defaults[gender].components
    return defaultMatchesVariant(defaults and defaults[componentId], variant, false)
end

local function shouldSkipPropGrant(propId, variant, gender)
    if not variant or tonumber(variant.drawable) == nil or tonumber(variant.drawable) < 0 then
        return true
    end

    local grantConfig = getAppearanceGrantConfig()
    if grantConfig.skipDefaults ~= true then return false end

    local defaults = Config.Defaults[gender] and Config.Defaults[gender].props
    return defaultMatchesVariant(defaults and defaults[propId], variant, true)
end

local function formatAppearanceItemLabel(def, variant)
    local grantConfig = getAppearanceGrantConfig()
    local label = def.label or def.item or 'Clothing'

    if grantConfig.includeDrawableInLabel ~= false and variant then
        label = ('%s D%s T%s'):format(label, tostring(variant.drawable), tostring(variant.texture or 0))
    end

    return label
end

local function componentMetadata(componentId, variant)
    return {
        component = componentId,
        drawable = tonumber(variant.drawable) or 0,
        texture = tonumber(variant.texture) or 0,
        collection = variant.collection or '',
    }
end

local function propMetadata(propId, variant)
    return {
        prop = propId,
        drawable = tonumber(variant.drawable) or -1,
        texture = tonumber(variant.texture) or 0,
        collection = variant.collection or '',
    }
end

local function buildOutfitBagClothingItems(outfit)
    local grantConfig = getAppearanceGrantConfig()
    if grantConfig.enabled ~= true then return {} end

    local ped = PlayerPedId()
    if not ped or ped == 0 or not DoesEntityExist(ped) then return {} end

    local appearance = outfit and outfit.appearance
    local featureMap = buildSavedOutfitFeatureMap(appearance)
    local gender = getPedGender(ped)
    local items = {}
    local torsoVariant

    for i = 1, #(grantConfig.components or {}) do
        local def = grantConfig.components[i]
        local componentId = tonumber(def.component)

        if componentId then
            local variant = getComponentSnapshot(ped, featureMap, def.feature or componentToFeatureId[componentId], componentId)

            if componentId == 3 then
                torsoVariant = variant
            end

            local skipTorsoItem = componentId == 3 and grantConfig.includeTorsoItem ~= true
            local skipDefault = shouldSkipComponentGrant(componentId, variant, gender)

            if not skipTorsoItem and not skipDefault then
                items[#items + 1] = {
                    item = def.item,
                    metadata = {
                        label = formatAppearanceItemLabel(def, variant),
                        image = def.image,
                        clothingSource = 'outfit_bag',
                        components = {
                            componentMetadata(componentId, variant),
                        },
                    },
                }
            end

            if componentId == 11 and not skipDefault and grantConfig.bundleTorsoWithJackets ~= false then
                local jacketItem = items[#items]
                if jacketItem and jacketItem.item == def.item and torsoVariant and tonumber(torsoVariant.drawable) and tonumber(torsoVariant.drawable) >= 0 then
                    table.insert(jacketItem.metadata.components, 1, componentMetadata(3, torsoVariant))
                end
            end
        end
    end

    for i = 1, #(grantConfig.props or {}) do
        local def = grantConfig.props[i]
        local propId = tonumber(def.prop)

        if propId then
            local variant = getPropSnapshot(ped, featureMap, def.feature or propToFeatureId[propId], propId)

            if not shouldSkipPropGrant(propId, variant, gender) then
                items[#items + 1] = {
                    item = def.item,
                    metadata = {
                        label = formatAppearanceItemLabel(def, variant),
                        image = def.image,
                        clothingSource = 'outfit_bag',
                        props = {
                            propMetadata(propId, variant),
                        },
                    },
                }
            end
        end
    end

    return items
end

local function grantCurrentOutfitClothingItems(outfit)
    local outfitConfig = getOutfitBagConfig()
    if outfitConfig.grantClothingItems ~= true then return end

    CreateThread(function()
        Wait(outfitConfig.grantClothingItemsDelayMs or 0)
        local items = buildOutfitBagClothingItems(outfit)

        if #items > 0 then
            TriggerServerEvent('cvn-clothingitems:server:addAppearanceItems', items)
            return
        end

        TriggerEvent('cvn-clothingitems:client:grantCurrentAppearanceItems')
    end)
end

local function getSelectedBagNetId(entity)
    if entity and entity ~= 0 and NetworkGetEntityIsNetworked(entity) then
        return NetworkGetNetworkIdFromEntity(entity)
    end

    return 0
end

local function buildOutfitBagTargetOptions(targetConfig, useDistance, nameSuffix)
    return {
        {
            name = ('cvn_outfitbag_change_%s'):format(nameSuffix),
            icon = targetConfig.changeIcon or 'fa-solid fa-shirt',
            label = 'Change Outfit',
            distance = useDistance,
            onSelect = function(data)
                local selectedEntity = data.entity
                if not selectedEntity or selectedEntity == 0 then return end

                local ok, message = lib.callback.await(
                    'cvn-clothingitems:server:openOutfitBag',
                    false,
                    getSelectedBagNetId(selectedEntity),
                    GetEntityCoords(selectedEntity)
                )

                if not ok and message then
                    notify(message, 'error')
                end
            end,
        },
        {
            name = ('cvn_outfitbag_pickup_%s'):format(nameSuffix),
            icon = targetConfig.pickupIcon or 'fa-solid fa-hand',
            label = 'Pick Up Bag',
            distance = useDistance,
            onSelect = function(data)
                local selectedEntity = data.entity
                if not selectedEntity or selectedEntity == 0 then return end

                local ok, message = lib.callback.await(
                    'cvn-clothingitems:server:pickupOutfitBag',
                    false,
                    getSelectedBagNetId(selectedEntity),
                    GetEntityCoords(selectedEntity)
                )

                notify(message or (ok and 'Picked up outfit bag.' or 'Could not pick up outfit bag.'), ok and 'success' or 'error')
            end,
        },
    }
end

RegisterNetEvent('cvn-clothingitems:client:useOutfitBag', function(itemData, slotData)
    local outfitConfig = getOutfitBagConfig()
    if outfitConfig.enabled ~= true then
        notify('Outfit bags are disabled.', 'error')
        return
    end

    local slot = type(slotData) == 'table' and slotData.slot or tonumber(slotData)
    if not slot and type(itemData) == 'table' then
        slot = itemData.slot
    end

    TriggerServerEvent('cvn-clothingitems:server:dropOutfitBag', slot)
end)

RegisterNetEvent('cvn-clothingitems:client:useOutfitCharge', function()
    local outfitConfig = getOutfitBagConfig()
    local chargeItem = outfitConfig.chargeItem or 'outfit_change_charge'

    notify(('Keep %s in your inventory. It is consumed when changing outfits from an outfit bag.'):format(chargeItem), 'inform')
end)

RegisterNetEvent('cvn-clothingitems:client:createOutfitBag', function(token)
    local outfitConfig = getOutfitBagConfig()
    if outfitConfig.enabled ~= true then return end

    local model = outfitConfig.bagModel or `prop_cs_heist_bag_02`
    if not requestModel(model, 5000) then
        TriggerServerEvent('cvn-clothingitems:server:registerOutfitBag', token, 0, vector3(0.0, 0.0, 0.0))
        notify('Could not load outfit bag model.', 'error')
        return
    end

    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local forward = GetEntityForwardVector(ped)
    local spawnCoords = coords + (forward * 0.8)
    local object = CreateObject(model, spawnCoords.x, spawnCoords.y, spawnCoords.z - 0.9, true, true, false)

    if not object or object == 0 then
        TriggerServerEvent('cvn-clothingitems:server:registerOutfitBag', token, 0, vector3(0.0, 0.0, 0.0))
        notify('Could not create outfit bag.', 'error')
        return
    end

    SetEntityAsMissionEntity(object, true, true)
    PlaceObjectOnGroundProperly(object)

    local netId = ObjToNet(object)
    SetNetworkIdExistsOnAllMachines(netId, true)
    SetNetworkIdCanMigrate(netId, true)

    TriggerServerEvent('cvn-clothingitems:server:registerOutfitBag', token, netId, GetEntityCoords(object))
    SetModelAsNoLongerNeeded(model)
end)

RegisterNetEvent('cvn-clothingitems:client:spawnOutfitBag', function(netId)
    CreateThread(function()
        local outfitConfig = getOutfitBagConfig()
        if outfitConfig.enabled ~= true then return end

        local targetResource = getTargetResource()
        if GetResourceState(targetResource) ~= 'started' then return end
        if outfitBagTargets[netId] then return end

        local targetConfig = type(outfitConfig.target) == 'table' and outfitConfig.target or {}
        if targetConfig.useModelTarget ~= false then
            return
        end

        local entity = getNetworkEntity(netId, targetConfig.registerTimeoutMs or 5000)
        if not entity then
            return
        end

        outfitBagTargets[netId] = true

        local useDistance = outfitConfig.useDistance or 2.2
        exports[targetResource]:addEntity(netId, buildOutfitBagTargetOptions(targetConfig, useDistance, netId))
    end)
end)

RegisterNetEvent('cvn-clothingitems:client:despawnOutfitBag', function(netId)
    local targetResource = getTargetResource()

    if GetResourceState(targetResource) == 'started' and outfitBagTargets[netId] then
        exports[targetResource]:removeEntity(netId)
    end

    outfitBagTargets[netId] = nil
    deleteNetworkEntity(netId)
end)

RegisterNetEvent('cvn-clothingitems:client:chooseOutfitBagOutfit', function(outfits, bagNetId)
    if type(outfits) ~= 'table' or #outfits == 0 then
        notify('You have no saved outfits.', 'error')
        return
    end

    local options = {}

    for i = 1, #outfits do
        local outfit = outfits[i]

        if type(outfit) == 'table' and outfit.appearance then
            options[#options + 1] = {
                title = outfit.name or ('Outfit %s'):format(tostring(outfit.id or i)),
                description = outfit.description or '',
                args = {
                    outfit = outfit,
                    bagNetId = bagNetId,
                },
                event = 'cvn-clothingitems:client:pickOutfitBagOutfit',
            }
        end
    end

    if #options == 0 then
        notify('No usable outfits were found.', 'error')
        return
    end

    lib.registerContext({
        id = 'cvn_clothingitems_outfitbag_menu',
        title = 'Select Outfit',
        options = options,
    })

    lib.showContext('cvn_clothingitems_outfitbag_menu')
end)

RegisterNetEvent('cvn-clothingitems:client:pickOutfitBagOutfit', function(ctx)
    local outfitConfig = getOutfitBagConfig()
    if outfitConfig.enabled ~= true then return end

    local outfit = ctx and ctx.outfit
    local bagNetId = ctx and ctx.bagNetId

    if not outfit or not bagNetId then return end

    local ok = lib.progressCircle({
        duration = outfitConfig.changeDelayMs or 45000,
        label = 'Changing clothes...',
        position = 'bottom',
        useWhileDead = false,
        canCancel = true,
        disable = {
            move = true,
            combat = true,
            car = true,
        },
    })

    if not ok then
        TriggerServerEvent('cvn-clothingitems:server:cancelOutfitBagChange', bagNetId)
        return
    end

    local chargeOk, chargeMessage = lib.callback.await(
        'cvn-clothingitems:server:consumeOutfitBagCharge',
        false,
        bagNetId,
        outfit.id
    )

    if not chargeOk then
        notify(chargeMessage or 'Could not use an outfit change charge.', 'error')
        return
    end

    local success = applyOutfit(outfit)

    if success then
        TriggerServerEvent('cvn-clothingitems:server:finishOutfitBagChange', bagNetId, outfit.id)
        grantCurrentOutfitClothingItems(outfit)
        notify('Changed outfit.', 'success')
    else
        TriggerServerEvent('cvn-clothingitems:server:failOutfitBagChange', bagNetId, outfit.id)
        notify('Failed to apply outfit.', 'error')
    end
end)

CreateThread(function()
    local outfitConfig = getOutfitBagConfig()
    if outfitConfig.enabled ~= true then return end

    local targetResource = getTargetResource()
    while GetResourceState(targetResource) ~= 'started' do
        Wait(1000)
    end

    local targetConfig = type(outfitConfig.target) == 'table' and outfitConfig.target or {}
    if targetConfig.useModelTarget == false then return end

    local model = outfitConfig.bagModel or `prop_cs_heist_bag_02`
    local useDistance = outfitConfig.useDistance or 2.2

    exports[targetResource]:addModel(model, buildOutfitBagTargetOptions(targetConfig, useDistance, 'model'))
end)
