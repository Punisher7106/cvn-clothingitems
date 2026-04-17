local resourceName = GetCurrentResourceName()

local function log(message)
    print(('[%s] %s'):format(resourceName, message))
end

local function notify(source, message)
    if source == 0 then
        log(message)
        return
    end

    TriggerClientEvent('chat:addMessage', source, {
        args = { 'CVN Clothing', message }
    })
end

local qbCoreObject
local esxObject

local function toList(value, fallback)
    if type(value) == 'table' then
        return value
    end

    if type(value) == 'string' and value ~= '' then
        return { value }
    end

    return fallback or {}
end

local function hasAceAccess(source)
    return IsPlayerAceAllowed(source, Config.Commands.ace)
end

local function hasQboxAccess(source)
    if GetResourceState('qbx_core') ~= 'started' then
        return false
    end

    local groups = toList(Config.Commands.qboxGroups, { 'admin', 'god' })

    for i = 1, #groups do
        local group = groups[i]

        local ok, hasGroup = pcall(function()
            return exports.qbx_core:HasGroup(source, group)
        end)

        if ok and hasGroup then
            return true
        end

        ok, hasGroup = pcall(function()
            return exports.qbx_core:HasPrimaryGroup(source, group)
        end)

        if ok and hasGroup then
            return true
        end

        ok, hasGroup = pcall(function()
            return exports.qbx_core:HasPermission(source, group)
        end)

        if ok and hasGroup then
            return true
        end
    end

    return false
end

local function getQBCoreObject()
    if qbCoreObject then
        return qbCoreObject
    end

    if GetResourceState('qb-core') ~= 'started' then
        return nil
    end

    local ok, core = pcall(function()
        return exports['qb-core']:GetCoreObject()
    end)

    if ok and type(core) == 'table' then
        qbCoreObject = core
        return qbCoreObject
    end

    return nil
end

local function getESXObject()
    if esxObject then
        return esxObject
    end

    if GetResourceState('es_extended') ~= 'started' then
        return nil
    end

    local ok, shared = pcall(function()
        return exports['es_extended']:getSharedObject()
    end)

    if ok and type(shared) == 'table' then
        esxObject = shared
        return esxObject
    end

    pcall(function()
        TriggerEvent('esx:getSharedObject', function(obj)
            esxObject = obj
        end)
    end)

    return esxObject
end

local function hasQBCoreAccess(source)
    local qbcore = getQBCoreObject()
    if not qbcore or type(qbcore.Functions) ~= 'table' then
        return false
    end

    local permissions = toList(Config.Commands.qbcorePermissions, { 'admin', 'god' })

    for i = 1, #permissions do
        local permission = permissions[i]

        if type(qbcore.Functions.HasPermission) == 'function' then
            local ok, allowed = pcall(function()
                return qbcore.Functions.HasPermission(source, permission)
            end)

            if ok and allowed then
                return true
            end
        end
    end

    if type(qbcore.Functions.GetPermission) == 'function' then
        local ok, currentPermissions = pcall(function()
            return qbcore.Functions.GetPermission(source)
        end)

        if ok then
            if type(currentPermissions) == 'table' then
                for i = 1, #permissions do
                    local permission = permissions[i]

                    if currentPermissions[permission] == true then
                        return true
                    end
                end
            elseif type(currentPermissions) == 'string' then
                for i = 1, #permissions do
                    if permissions[i] == currentPermissions then
                        return true
                    end
                end
            end
        end
    end

    return false
end

local function hasESXAccess(source)
    local esx = getESXObject()
    if not esx or type(esx.GetPlayerFromId) ~= 'function' then
        return false
    end

    local xPlayer = esx.GetPlayerFromId(source)
    if not xPlayer then
        return false
    end

    local group

    if type(xPlayer.getGroup) == 'function' then
        local ok, value = pcall(function()
            return xPlayer.getGroup()
        end)

        if ok and type(value) == 'string' then
            group = value
        end
    end

    if type(group) ~= 'string' and type(xPlayer.group) == 'string' then
        group = xPlayer.group
    end

    if type(group) ~= 'string' then
        return false
    end

    local groups = toList(Config.Commands.esxGroups, { 'admin', 'superadmin' })

    for i = 1, #groups do
        if groups[i] == group then
            return true
        end
    end

    return false
end

local function hasAccess(source)
    if source == 0 then return true end
    if not Config.Commands.adminOnly then return true end

    local provider = tostring(Config.Commands.adminProvider or 'auto'):lower()

    if provider == 'ace' then
        return hasAceAccess(source)
    end

    if provider == 'qbox' then
        if hasQboxAccess(source) then return true end
        return Config.Commands.allowAceFallback == true and hasAceAccess(source) or false
    end

    if provider == 'qbcore' then
        if hasQBCoreAccess(source) then return true end
        return Config.Commands.allowAceFallback == true and hasAceAccess(source) or false
    end

    if provider == 'esx' then
        if hasESXAccess(source) then return true end
        return Config.Commands.allowAceFallback == true and hasAceAccess(source) or false
    end

    if provider == 'auto' then
        if hasQboxAccess(source) then return true end
        if hasQBCoreAccess(source) then return true end
        if hasESXAccess(source) then return true end
        return Config.Commands.allowAceFallback ~= false and hasAceAccess(source) or false
    end

    return Config.Commands.allowAceFallback ~= false and hasAceAccess(source) or false
end

local function commandDenied(source)
    notify(source, 'You do not have permission to use this command.')
end

local variantsCache
local variantsCacheStamp = 0

local function loadVariants(force)
    local now = GetGameTimer()

    if not force and variantsCache and (now - variantsCacheStamp) < (Config.Variants.cacheMs or 0) then
        return variantsCache
    end

    local raw = LoadResourceFile(Config.Variants.resource, Config.Variants.file)
    if not raw then
        return nil, ('Could not read %s/%s'):format(Config.Variants.resource, Config.Variants.file)
    end

    local ok, decoded = pcall(json.decode, raw)
    if not ok or type(decoded) ~= 'table' then
        return nil, 'variantsMetadata.json is not valid JSON.'
    end

    variantsCache = decoded
    variantsCacheStamp = now

    return variantsCache
end

local function sortedKeys(tbl)
    local keys = {}

    for key in pairs(tbl) do
        keys[#keys + 1] = key
    end

    table.sort(keys)

    return keys
end

local function getTextureIds(variant)
    local ids = {}
    local textures = variant.textures

    if type(textures) == 'table' and #textures > 0 then
        for index, value in ipairs(textures) do
            local textureId

            if type(value) == 'table' then
                textureId = tonumber(value.id)
                if textureId == nil then
                    textureId = index - 1
                end
            else
                textureId = tonumber(value)
                if textureId == nil then
                    textureId = index - 1
                end
            end

            ids[#ids + 1] = textureId
        end
    else
        ids[1] = 0
    end

    table.sort(ids)

    local unique = {}
    local dedupe = {}

    for i = 1, #ids do
        local id = ids[i]

        if not dedupe[id] then
            dedupe[id] = true
            unique[#unique + 1] = id
        end
    end

    return unique
end

local function getModelData(source, model)
    local data, loadError = loadVariants(false)
    if not data then
        notify(source, loadError)
        return
    end

    local modelData = data[model]
    if type(modelData) ~= 'table' then
        notify(source, ('Model not found: %s'):format(model))
        return
    end

    return data, modelData
end

local function getCategoryList(modelData)
    local categories = {}

    for category, variants in pairs(modelData) do
        if type(variants) == 'table' and #variants > 0 then
            categories[#categories + 1] = category
        end
    end

    table.sort(categories)

    return categories
end

local function splitOutput(source, prefix, entries)
    if #entries == 0 then
        notify(source, prefix .. ' none')
        return
    end

    local limit = Config.Commands.previewLimit or 20
    local batch = {}

    for i = 1, #entries do
        batch[#batch + 1] = entries[i]

        if #batch >= limit or i == #entries then
            notify(source, prefix .. ' ' .. table.concat(batch, ', '))
            batch = {}
        end
    end
end

local function registerCvnCommand(name, handler)
    RegisterCommand(name, function(source, args, raw)
        if not hasAccess(source) then
            commandDenied(source)
            return
        end

        local ok, err = pcall(handler, source, args, raw)
        if not ok then
            log(('Command %s failed: %s'):format(name, tostring(err)))
            notify(source, 'Command failed. Check server console for details.')
        end
    end, false)
end

registerCvnCommand('cvnreloadvariants', function(source)
    local data, err = loadVariants(true)
    if not data then
        notify(source, err)
        return
    end

    notify(source, 'Reloaded variants metadata cache.')
end)

registerCvnCommand('cvnmodels', function(source)
    local data, err = loadVariants(false)
    if not data then
        notify(source, err)
        return
    end

    local models = sortedKeys(data)
    notify(source, ('Found %d models.'):format(#models))
    splitOutput(source, 'Models:', models)
end)

registerCvnCommand('cvncategories', function(source, args)
    local model = args[1]
    if not model then
        notify(source, 'Usage: /cvncategories <model>')
        return
    end

    local _, modelData = getModelData(source, model)
    if not modelData then return end

    local categories = getCategoryList(modelData)
    notify(source, ('Model %s has %d categories.'):format(model, #categories))
    splitOutput(source, 'Categories:', categories)
end)

registerCvnCommand('cvncollections', function(source, args)
    local model = args[1]
    local category = args[2]

    if not model or not category then
        notify(source, 'Usage: /cvncollections <model> <category>')
        return
    end

    local _, modelData = getModelData(source, model)
    if not modelData then return end

    local variants = modelData[category]
    if type(variants) ~= 'table' or #variants == 0 then
        notify(source, ('Category not found or empty: %s'):format(category))
        return
    end

    local collections = {}
    local counts = {}

    for i = 1, #variants do
        local variant = variants[i]

        if variant.type == 'drawable' or variant.type == 'prop' then
            local collection = variant.collection or ''
            if collection ~= '' then
                if not counts[collection] then
                    collections[#collections + 1] = collection
                    counts[collection] = 0
                end

                counts[collection] = counts[collection] + 1
            end
        end
    end

    table.sort(collections)

    if #collections == 0 then
        notify(source, 'No non-empty collections were found in this category.')
        return
    end

    local output = {}

    for i = 1, #collections do
        local name = collections[i]
        output[#output + 1] = ('%s (%d)'):format(name, counts[name])
    end

    notify(source, ('Category %s has %d collections.'):format(category, #collections))
    splitOutput(source, 'Collections:', output)
end)

registerCvnCommand('cvnvariants', function(source, args)
    local model = args[1]
    local category = args[2]
    local collectionFilter = args[3]
    local limit = tonumber(args[4]) or (Config.Commands.previewLimit or 20)

    if not model or not category then
        notify(source, 'Usage: /cvnvariants <model> <category> [collection|all] [limit]')
        return
    end

    local _, modelData = getModelData(source, model)
    if not modelData then return end

    local variants = modelData[category]
    if type(variants) ~= 'table' or #variants == 0 then
        notify(source, ('Category not found or empty: %s'):format(category))
        return
    end

    local lines = {}

    for i = 1, #variants do
        local variant = variants[i]

        if variant.type == 'drawable' or variant.type == 'prop' then
            local collection = variant.collection or ''

            if not collectionFilter or collectionFilter == 'all' or collection == collectionFilter then
                local textures = getTextureIds(variant)
                lines[#lines + 1] = ('%s id=%s component=%s textures=%d collection=%s'):format(
                    variant.type,
                    tostring(variant.id),
                    tostring(variant.componentId),
                    #textures,
                    collection ~= '' and collection or 'none'
                )

                if #lines >= limit then
                    break
                end
            end
        end
    end

    notify(source, ('Showing %d variants from %s/%s.'):format(#lines, model, category))
    splitOutput(source, 'Variants:', lines)
end)

local clothingPresetAliases = {}

local function deepCopy(value)
    if type(value) ~= 'table' then
        return value
    end

    local copy = {}

    for key, child in pairs(value) do
        copy[key] = deepCopy(child)
    end

    return copy
end

local function normalizePresetKey(value)
    if type(value) ~= 'string' then return nil end

    local key = value:lower()
    key = key:gsub('[%s%-]+', '_')
    key = key:gsub('[^%w_]', '')
    key = key:gsub('_+', '_')
    key = key:gsub('^_+', ''):gsub('_+$', '')

    return clothingPresetAliases[key] or key
end

local function getClothingPreset(presetName)
    local key = normalizePresetKey(presetName)
    if not key then return nil, nil end

    local presets = type(Config.ClothingPresets) == 'table' and Config.ClothingPresets or {}
    return key, presets[key]
end

local function buildPresetMetadata(presetKey, preset, entry)
    local metadata = {}

    for key, value in pairs(entry) do
        if key ~= 'item' and key ~= 'count' then
            metadata[key] = deepCopy(value)
        end
    end

    metadata.clothingPreset = presetKey
    metadata.clothingPresetLabel = preset.label

    return metadata
end

local function addInventoryItem(target, itemName, count, metadata)
    local inventoryConfig = type(Config.Inventory) == 'table' and Config.Inventory or {}
    local customInventory = type(inventoryConfig.custom) == 'table' and inventoryConfig.custom or {}

    if type(customInventory.addItem) == 'function' then
        local ok, success, response = pcall(customInventory.addItem, target, itemName, count, metadata)
        if ok then
            return success ~= false, response
        end

        return false, success
    end

    local provider = tostring(inventoryConfig.provider or 'ox'):lower()
    if provider ~= 'ox' then
        return false, ('Inventory provider %s needs Config.Inventory.custom.addItem.'):format(provider)
    end

    local ok, success, response = pcall(function()
        return exports.ox_inventory:AddItem(target, itemName, count, metadata)
    end)

    if not ok then
        return false, success
    end

    return success == true, response
end

local function getInventoryItemSlots(target, itemName)
    local inventoryConfig = type(Config.Inventory) == 'table' and Config.Inventory or {}
    local customInventory = type(inventoryConfig.custom) == 'table' and inventoryConfig.custom or {}

    if type(customInventory.findItems) == 'function' then
        local ok, items = pcall(customInventory.findItems, target, itemName)
        if ok and type(items) == 'table' then
            return items
        end
    end

    local provider = tostring(inventoryConfig.provider or 'ox'):lower()
    if provider ~= 'ox' then
        return {}
    end

    local ok, items = pcall(function()
        return exports.ox_inventory:Search(target, 'slots', itemName)
    end)

    if ok and type(items) == 'table' then
        return items
    end

    ok, items = pcall(function()
        return exports.ox_inventory:GetInventoryItems(target)
    end)

    if not ok or type(items) ~= 'table' then
        return {}
    end

    local filtered = {}

    for _, item in pairs(items) do
        if type(item) == 'table' and item.name == itemName then
            filtered[#filtered + 1] = item
        end
    end

    return filtered
end

local appearanceGrantCooldowns = {}

local function getAppearanceGrantConfig()
    return type(Config.AppearanceItemGrant) == 'table' and Config.AppearanceItemGrant or {}
end

local function sanitizeText(value, fallback, maxLength)
    if type(value) ~= 'string' or value == '' then
        return fallback
    end

    value = value:gsub('[\r\n]', ' ')
    maxLength = maxLength or 80

    if #value > maxLength then
        value = value:sub(1, maxLength)
    end

    return value
end

local function buildAppearanceGrantRules()
    local grantConfig = getAppearanceGrantConfig()
    local rules = {}

    for i = 1, #(grantConfig.components or {}) do
        local def = grantConfig.components[i]
        if type(def) == 'table' and type(def.item) == 'string' and def.component ~= nil then
            local itemRules = rules[def.item] or {
                label = def.label,
                image = def.image,
                components = {},
                props = {},
            }

            itemRules.components[tonumber(def.component)] = true
            itemRules.label = itemRules.label or def.label
            itemRules.image = itemRules.image or def.image

            if tonumber(def.component) == 11 and grantConfig.bundleTorsoWithJackets ~= false then
                itemRules.components[3] = true
            end

            rules[def.item] = itemRules
        end
    end

    for i = 1, #(grantConfig.props or {}) do
        local def = grantConfig.props[i]
        if type(def) == 'table' and type(def.item) == 'string' and def.prop ~= nil then
            local itemRules = rules[def.item] or {
                label = def.label,
                image = def.image,
                components = {},
                props = {},
            }

            itemRules.props[tonumber(def.prop)] = true
            itemRules.label = itemRules.label or def.label
            itemRules.image = itemRules.image or def.image
            rules[def.item] = itemRules
        end
    end

    return rules
end

local function sanitizeAppearanceComponent(entry, rules)
    if type(entry) ~= 'table' then return nil end

    local componentId = tonumber(entry.component)
    if not componentId or not rules.components[componentId] then return nil end

    local drawable = tonumber(entry.drawable)
    if not drawable then return nil end

    return {
        component = componentId,
        drawable = drawable,
        texture = tonumber(entry.texture) or 0,
        collection = sanitizeText(entry.collection, '', 64),
    }
end

local function sanitizeAppearanceProp(entry, rules)
    if type(entry) ~= 'table' then return nil end

    local propId = tonumber(entry.prop)
    if not propId or not rules.props[propId] then return nil end

    local drawable = tonumber(entry.drawable)
    if not drawable or drawable < 0 then return nil end

    return {
        prop = propId,
        drawable = drawable,
        texture = tonumber(entry.texture) or 0,
        collection = sanitizeText(entry.collection, '', 64),
    }
end

local function sanitizeAppearanceGrantItem(entry, rulesByItem)
    if type(entry) ~= 'table' or type(entry.item) ~= 'string' then return nil end

    local itemName = entry.item
    local itemRules = rulesByItem[itemName]
    if not itemRules then return nil end

    local metadata = type(entry.metadata) == 'table' and entry.metadata or {}
    local sanitized = {
        label = sanitizeText(metadata.label, itemRules.label or itemName, 80),
        image = sanitizeText(itemRules.image, nil, 64),
        clothingSource = 'appearance_menu',
    }

    if type(metadata.components) == 'table' then
        sanitized.components = {}

        for i = 1, math.min(#metadata.components, 3) do
            local component = sanitizeAppearanceComponent(metadata.components[i], itemRules)
            if component then
                sanitized.components[#sanitized.components + 1] = component
            end
        end

        if #sanitized.components == 0 then
            sanitized.components = nil
        end
    end

    if type(metadata.props) == 'table' then
        sanitized.props = {}

        for i = 1, math.min(#metadata.props, 2) do
            local prop = sanitizeAppearanceProp(metadata.props[i], itemRules)
            if prop then
                sanitized.props[#sanitized.props + 1] = prop
            end
        end

        if #sanitized.props == 0 then
            sanitized.props = nil
        end
    end

    if not sanitized.components and not sanitized.props then
        return nil
    end

    return itemName, sanitized
end

local function addVariantSignature(signatures, kind, id, drawable, texture, collection)
    id = tonumber(id)
    drawable = tonumber(drawable)

    if not id or drawable == nil then return end

    signatures[('%s:%s:%s:%s:%s'):format(
        kind,
        id,
        drawable,
        tonumber(texture) or 0,
        tostring(collection or '')
    )] = true
end

local function addGenderVariantSignatures(signatures, kind, id, entry)
    if type(entry) ~= 'table' then return end

    addVariantSignature(signatures, kind, id, entry.drawable, entry.texture, entry.collection)

    local genderKeys = { 'male', 'female', 'any' }

    for i = 1, #genderKeys do
        local genderVariant = entry[genderKeys[i]]
        if type(genderVariant) == 'table' then
            addVariantSignature(
                signatures,
                kind,
                id,
                genderVariant.drawable,
                genderVariant.texture,
                genderVariant.collection or entry.collection
            )
        end
    end
end

local function getClothingSignatures(metadata)
    local signatures = {}

    if type(metadata) ~= 'table' then
        return signatures
    end

    if type(metadata.components) == 'table' then
        for i = 1, #metadata.components do
            local component = metadata.components[i]
            addGenderVariantSignatures(signatures, 'component', component and component.component, component)
        end
    end

    if metadata.component ~= nil then
        addGenderVariantSignatures(signatures, 'component', metadata.component, metadata)
    end

    if type(metadata.props) == 'table' then
        for i = 1, #metadata.props do
            local prop = metadata.props[i]
            addGenderVariantSignatures(signatures, 'prop', prop and prop.prop, prop)
        end
    end

    if metadata.prop ~= nil then
        addGenderVariantSignatures(signatures, 'prop', metadata.prop, metadata)
    end

    return signatures
end

local function metadataHasRequiredSignatures(existingMetadata, requiredSignatures)
    local existingSignatures = getClothingSignatures(existingMetadata)
    local hasRequired = false

    for signature in pairs(requiredSignatures) do
        hasRequired = true

        if not existingSignatures[signature] then
            return false
        end
    end

    return hasRequired
end

local function hasMatchingClothingItem(target, itemName, metadata, inventoryCache)
    local requiredSignatures = getClothingSignatures(metadata)
    if next(requiredSignatures) == nil then return false end

    inventoryCache[itemName] = inventoryCache[itemName] or getInventoryItemSlots(target, itemName)
    local items = inventoryCache[itemName]

    for _, item in pairs(items) do
        local existingMetadata = type(item) == 'table' and (item.metadata or item.info) or nil

        if existingMetadata and metadataHasRequiredSignatures(existingMetadata, requiredSignatures) then
            return true
        end
    end

    return false
end

local function getMetadataSignatureKey(itemName, metadata)
    local signatures = getClothingSignatures(metadata)
    local keys = {}

    for signature in pairs(signatures) do
        keys[#keys + 1] = signature
    end

    if #keys == 0 then return nil end

    table.sort(keys)
    return itemName .. '|' .. table.concat(keys, '|')
end

local function wasRecentlyGranted(source, signatureKey, now, cooldownMs)
    if cooldownMs <= 0 or not signatureKey then return false end

    local recent = appearanceGrantCooldowns[source]
    if type(recent) ~= 'table' or now - (recent.time or 0) >= cooldownMs then
        return false
    end

    return type(recent.signatures) == 'table' and recent.signatures[signatureKey] == true
end

local function storeRecentGrantSignatures(source, signatures, now)
    if next(signatures) == nil then return end

    appearanceGrantCooldowns[source] = {
        time = now,
        signatures = signatures,
    }
end

local function addAppearanceClothingItems(source, items)
    local grantConfig = getAppearanceGrantConfig()
    if grantConfig.enabled ~= true then
        return false, 'Appearance clothing item grants are disabled.'
    end

    if type(items) ~= 'table' then
        return false, 'Invalid appearance clothing item payload.'
    end

    local now = GetGameTimer()
    local cooldownMs = tonumber(grantConfig.cooldownMs) or 0
    local rulesByItem = buildAppearanceGrantRules()
    local added = 0
    local skippedExisting = 0
    local recentGrantSignatures = {}
    local inventoryCache = {}
    local maxItems = math.min(#items, 20)

    for i = 1, maxItems do
        local itemName, metadata = sanitizeAppearanceGrantItem(items[i], rulesByItem)

        if itemName and metadata then
            local signatureKey = getMetadataSignatureKey(itemName, metadata)

            if wasRecentlyGranted(source, signatureKey, now, cooldownMs) then
                skippedExisting = skippedExisting + 1
            elseif grantConfig.skipExisting ~= false and hasMatchingClothingItem(source, itemName, metadata, inventoryCache) then
                skippedExisting = skippedExisting + 1
            else
                local success, response = addInventoryItem(source, itemName, 1, metadata)
                if not success then
                    return false, ('Failed to add %s: %s'):format(itemName, tostring(response))
                end

                added = added + 1
                if signatureKey then
                    recentGrantSignatures[signatureKey] = true
                end

                if inventoryCache[itemName] then
                    inventoryCache[itemName][#inventoryCache[itemName] + 1] = {
                        name = itemName,
                        metadata = metadata,
                    }
                end
            end
        end
    end

    if added == 0 then
        if skippedExisting > 0 then
            return true, 'You already have matching clothing items for this outfit.', 0
        end

        return true, 'No new clothing items were added from this outfit.', 0
    end

    storeRecentGrantSignatures(source, recentGrantSignatures, now)

    if skippedExisting > 0 then
        return true, ('Added %d clothing item(s) from your current outfit. Skipped %d already owned.'):format(added, skippedExisting), added
    end

    return true, ('Added %d clothing item(s) from your current outfit.'):format(added), added
end

RegisterNetEvent('cvn-clothingitems:server:addAppearanceItems', function(items)
    local src = source
    local _, message = addAppearanceClothingItems(src, items)
    local grantConfig = getAppearanceGrantConfig()

    if grantConfig.notify ~= false then
        notify(src, message)
    end
end)

AddEventHandler('playerDropped', function()
    appearanceGrantCooldowns[source] = nil
end)

local function giveClothingSet(target, presetName)
    target = tonumber(target)
    if not target or target < 1 then
        return false, 'Invalid target player id.'
    end

    local presetKey, preset = getClothingPreset(presetName)
    if type(preset) ~= 'table' or type(preset.items) ~= 'table' then
        return false, ('Unknown clothing preset: %s'):format(tostring(presetName))
    end

    local added = 0

    for i = 1, #preset.items do
        local entry = preset.items[i]
        local itemName = entry and entry.item

        if type(itemName) ~= 'string' or itemName == '' then
            return false, ('Preset %s has an invalid item at index %d.'):format(presetKey, i)
        end

        local metadata = buildPresetMetadata(presetKey, preset, entry)
        local success, response = addInventoryItem(target, itemName, entry.count or 1, metadata)

        if not success then
            return false, ('Failed to add %s for %s: %s'):format(itemName, preset.label or presetKey, tostring(response))
        end

        added = added + 1
    end

    return true, ('Gave %s clothing set (%d items).'):format(preset.label or presetKey, added), preset.label or presetKey
end

registerCvnCommand('cvngiveclothingset', function(source, args)
    local target = tonumber(args[1])
    local presetName = args[2]

    if not target or not presetName then
        notify(source, 'Usage: /cvngiveclothingset <playerId> <presetKey>')
        return
    end

    local success, message, presetLabel = giveClothingSet(target, presetName)
    notify(source, message)

    if success and source ~= target then
        notify(target, ('Received clothing set: %s'):format(presetLabel))
    end
end)

RegisterNetEvent('cvn-clothingitems:server:giveClothingSet', function(target, presetName)
    local src = source

    if not hasAccess(src) then
        commandDenied(src)
        return
    end

    local targetId = tonumber(target)
    local success, message, presetLabel = giveClothingSet(targetId, presetName)
    notify(src, message)

    if success and src ~= targetId then
        notify(targetId, ('Received clothing set: %s'):format(presetLabel))
    end
end)

exports('giveClothingSet', giveClothingSet)
exports('getClothingPresets', function()
    return Config.ClothingPresets
end)

CreateThread(function()
    local data, err = loadVariants(false)
    if data then
        log(('Loaded variants metadata from %s/%s'):format(Config.Variants.resource, Config.Variants.file))
    else
        log(('Could not preload variants metadata: %s'):format(err))
    end
end)
