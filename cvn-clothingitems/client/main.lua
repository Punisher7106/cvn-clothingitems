if not lib then return end

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

local clothingToggleDefinitions = {
    gloves = { kind = 'component', component = 3, offDrawable = 15, offTexture = 0 },
    hat = { kind = 'prop', prop = 0, offDrawable = -1 },
    visor = { kind = 'prop', prop = 0, offDrawable = -1 },
    glasses = { kind = 'prop', prop = 1, offDrawable = -1 },
    glasses_special = {
        kind = 'prop',
        prop = 1,
        offDrawable = -1,
        allowOff = false,
        variants = {
            {
                genderVariants = {
                    male = { drawable = 64, texture = 0 },
                    female = { drawable = 66, texture = 0 },
                },
            },
            {
                genderVariants = {
                    male = { drawable = 66, texture = 0 },
                    female = { drawable = 68, texture = 0 },
                },
            },
        },
    },
    ears = { kind = 'prop', prop = 2, offDrawable = -1 },
    mask = { kind = 'component', component = 1, offDrawable = 0, offTexture = 0 },
    vest = { kind = 'component', component = 9, offDrawable = 0, offTexture = 0 },
    bag = { kind = 'component', component = 5, offDrawable = 0, offTexture = 0 },
    watch = { kind = 'prop', prop = 6, offDrawable = -1 },
    bracelet = { kind = 'prop', prop = 7, offDrawable = -1 },
}

local clothingToggleStates = {}
local appearanceHooksRegistered = false

local function normalizeToggleDefinition(def)
    if type(def) ~= 'table' then return nil end

    local normalized = {}

    for key, value in pairs(def) do
        normalized[key] = value
    end

    if not normalized.kind then
        if normalized.component ~= nil then
            normalized.kind = 'component'
        elseif normalized.prop ~= nil then
            normalized.kind = 'prop'
        end
    end

    if normalized.kind ~= 'component' and normalized.kind ~= 'prop' then
        return nil
    end

    return normalized
end

local function loadLuaTableFromResource(resource, filePath)
    if type(LoadResourceFile) ~= 'function' then return nil end

    local raw = LoadResourceFile(resource, filePath)
    if type(raw) ~= 'string' or raw == '' then
        return nil
    end

    local chunk = load(raw, ('@@%s/%s'):format(resource, filePath), 't', {})
    if type(chunk) ~= 'function' then
        return nil
    end

    local ok, data = pcall(chunk)
    if not ok or type(data) ~= 'table' then
        return nil
    end

    return data
end

local function mergeToggleDefinitions(definitions)
    for key, data in pairs(definitions or {}) do
        local normalized = normalizeToggleDefinition(data)
        if normalized then
            clothingToggleDefinitions[key] = normalized
        end
    end
end

mergeToggleDefinitions(loadLuaTableFromResource('ox_inventory', 'data/clothing_toggles.lua'))

local function getPedGender(ped)
    return GetEntityModel(ped) == `mp_f_freemode_01` and 'female' or 'male'
end

local function getAppearanceGrantConfig()
    return type(Config.AppearanceItemGrant) == 'table' and Config.AppearanceItemGrant or {}
end

local function is4bitEnabled()
    return GetResourceState(Config.Variants.resource) == 'started'
end

local function getDefaultTarget(kind, id, gender)
    local genderDefaults = Config.Defaults[gender] or {}
    local defaults = kind == 'prop' and genderDefaults.props or genderDefaults.components
    local selected = defaults and defaults[id]

    if not selected then
        selected = kind == 'prop' and Config.FallbackDefaults.prop or Config.FallbackDefaults.component
    end

    return {
        kind = kind,
        id = id,
        drawable = selected.drawable,
        texture = selected.texture,
        randomTexture = selected.randomTexture,
        collection = selected.collection or '',
    }
end

local function pickTextureFromTable(value)
    if type(value) ~= 'table' then return nil end

    local minValue = tonumber(value.min)
    local maxValue = tonumber(value.max)

    if minValue ~= nil and maxValue ~= nil then
        if maxValue < minValue then
            minValue, maxValue = maxValue, minValue
        end

        return math.random(minValue, maxValue)
    end

    if #value > 0 then
        local index = math.random(1, #value)
        return tonumber(value[index]) or 0
    end

    return nil
end

local function resolveTextureValue(ped, target)
    if target.kind == 'prop' and target.drawable == -1 then
        return 0
    end

    local texture = target.texture

    if type(texture) == 'number' then
        return texture
    end

    local picked = pickTextureFromTable(texture)
    if picked ~= nil then
        return picked
    end

    local randomTexture = target.randomTexture
    if randomTexture then
        local randomPicked = pickTextureFromTable(randomTexture)
        if randomPicked ~= nil then
            return randomPicked
        end
    end

    if texture == 'random' or randomTexture == true then
        if target.kind == 'component' then
            local maxTexture = GetNumberOfPedTextureVariations(ped, target.id, target.drawable)
            if maxTexture and maxTexture > 0 then
                return math.random(0, maxTexture - 1)
            end
        else
            local maxTexture = GetNumberOfPedPropTextureVariations(ped, target.id, target.drawable)
            if maxTexture and maxTexture > 0 then
                return math.random(0, maxTexture - 1)
            end
        end
    end

    return 0
end

local function resolveVariant(entry, gender)
    local genderVariant = entry[gender]

    if type(genderVariant) == 'table' and genderVariant.drawable ~= nil then
        return {
            drawable = genderVariant.drawable,
            texture = genderVariant.texture or 0,
            collection = genderVariant.collection or entry.collection or '',
        }
    end

    if entry.drawable == nil then return nil end

    return {
        drawable = entry.drawable,
        texture = entry.texture or 0,
        collection = entry.collection or '',
    }
end

local function update4bitFeature(kind, id, drawable, texture, collection)
    local featureId = kind == 'prop' and propToFeatureId[id] or componentToFeatureId[id]
    if not featureId then return end

    pcall(function()
        if kind == 'prop' then
            exports['4bit_appearance']:updateFeature({
                id = featureId,
                type = 'prop',
                componentId = id,
                values = {
                    drawable = drawable,
                    texture = texture or 0,
                    collection = collection or '',
                },
            })
            return
        end

        exports['4bit_appearance']:updateFeature({
            id = featureId,
            type = 'drawable',
            values = {
                drawable = drawable,
                texture = texture or 0,
                collection = collection or '',
            },
        })
    end)
end

local function applyTarget(ped, target, use4bit)
    local resolvedTexture = resolveTextureValue(ped, target)

    if target.kind == 'component' then
        local valid = IsPedComponentVariationValid(ped, target.id, target.drawable, resolvedTexture)
        if not valid and target.id == 10 then
            -- Component 10 (decals) can fail native validity checks while still applying in-game.
            valid = true
        end

        if valid then
            SetPedComponentVariation(ped, target.id, target.drawable, resolvedTexture, 0)
        end

        if use4bit then
            update4bitFeature('component', target.id, target.drawable, resolvedTexture, target.collection)
        end

        return valid or use4bit
    end

    if target.drawable == -1 then
        ClearPedProp(ped, target.id)

        if use4bit then
            update4bitFeature('prop', target.id, -1, -1, '')
        end

        return true
    end

    local maxDrawable = GetNumberOfPedPropDrawableVariations(ped, target.id)
    if maxDrawable <= 0 or target.drawable >= maxDrawable then
        if use4bit then
            update4bitFeature('prop', target.id, target.drawable, resolvedTexture, target.collection)
            return true
        end

        return false
    end

    local maxTexture = GetNumberOfPedPropTextureVariations(ped, target.id, target.drawable)
    if maxTexture > 0 and resolvedTexture >= maxTexture then
        if use4bit then
            update4bitFeature('prop', target.id, target.drawable, resolvedTexture, target.collection)
            return true
        end

        return false
    end

    SetPedPropIndex(ped, target.id, target.drawable, resolvedTexture, true)

    if use4bit then
        update4bitFeature('prop', target.id, target.drawable, resolvedTexture, target.collection)
    end

    return true
end

local function targetMatchesPed(ped, target)
    if target.kind == 'component' then
        return GetPedDrawableVariation(ped, target.id) == target.drawable
            and GetPedTextureVariation(ped, target.id) == target.texture
    end

    local drawable = GetPedPropIndex(ped, target.id)
    if drawable ~= target.drawable then return false end

    if drawable == -1 then return true end

    return GetPedPropTextureIndex(ped, target.id) == target.texture
end

local function sync4bitAppearance()
    pcall(function()
        local appearance = exports['4bit_appearance']:getAppearance()
        if appearance then
            exports['4bit_appearance']:setAppearance(appearance, true)
        end
    end)
end

local function captureToggleVariant(def, ped)
    if not def or not ped then return nil end

    if def.kind == 'component' then
        return {
            drawable = GetPedDrawableVariation(ped, def.component),
            texture = GetPedTextureVariation(ped, def.component),
            collection = def.collection or '',
        }
    end

    return {
        drawable = GetPedPropIndex(ped, def.prop),
        texture = GetPedPropTextureIndex(ped, def.prop),
        collection = '',
    }
end

local function hasPropEquipped(def, ped)
    if not def or not ped then return false end
    if def.kind ~= 'prop' then return true end
    return GetPedPropIndex(ped, def.prop) ~= -1
end

local function getGenderVariant(def, gender)
    if not def or not def.genderVariants then return nil end
    return def.genderVariants[gender] or def.genderVariants.any
end

local function getVariantForStage(def, stage, gender)
    if not def or not def.variants or not stage or stage < 1 then return nil end

    local variantDef = def.variants[stage]
    if not variantDef then return nil end

    local variant = getGenderVariant(variantDef, gender)
    if variant and variant.drawable ~= nil then
        return variant
    end

    if variantDef.drawable ~= nil then
        return variantDef
    end

    return nil
end

local function applyToggleVariant(def, variant, use4bit)
    if not def or not variant then return false end

    local ped = PlayerPedId()
    if not ped or ped == 0 or not DoesEntityExist(ped) then return false end

    if def.kind == 'component' then
        return applyTarget(ped, {
            kind = 'component',
            id = def.component,
            drawable = variant.drawable,
            texture = variant.texture or 0,
            collection = variant.collection or def.collection or '',
        }, use4bit)
    end

    return applyTarget(ped, {
        kind = 'prop',
        id = def.prop,
        drawable = variant.drawable,
        texture = variant.texture or 0,
        collection = variant.collection or def.collection or '',
    }, use4bit)
end

local function clearToggle(def, state, ped, gender, use4bit)
    if not def then return end

    if state and state.savedVariant then
        applyToggleVariant(def, state.savedVariant, use4bit)
        state.savedVariant = nil
        return
    end

    if def.kind == 'component' then
        local offDrawable = def.offDrawable
        local offTexture = def.offTexture

        if offDrawable == nil then
            local fallback = getDefaultTarget('component', def.component, gender)
            offDrawable = fallback.drawable
            offTexture = fallback.texture
        end

        applyTarget(ped, {
            kind = 'component',
            id = def.component,
            drawable = offDrawable,
            texture = offTexture or 0,
            collection = def.collection or '',
        }, use4bit)
    else
        local offDrawable = def.offDrawable
        if offDrawable == nil then
            offDrawable = -1
        end

        if offDrawable == -1 then
            applyTarget(ped, {
                kind = 'prop',
                id = def.prop,
                drawable = -1,
                texture = 0,
                collection = '',
            }, use4bit)
        else
            applyTarget(ped, {
                kind = 'prop',
                id = def.prop,
                drawable = offDrawable,
                texture = def.offTexture or 0,
                collection = def.collection or '',
            }, use4bit)
        end
    end
end

local function advanceVariantStage(def, state, gender)
    local variants = def and def.variants
    if not variants or #variants == 0 then
        return 0
    end

    local allowOff = def.allowOff ~= false
    local nextStage = state.stage or 0

    for _ = 1, (#variants + (allowOff and 1 or 0)) do
        nextStage = nextStage + 1

        if nextStage > #variants then
            if allowOff then
                return 0
            end
            nextStage = 1
        end

        if getVariantForStage(def, nextStage, gender) then
            return nextStage
        end
    end

    return 0
end

local function applyVariantStage(def, state, stage, ped, gender, use4bit)
    if not def or not state or stage < 1 then return false end
    if def.kind == 'prop' and not hasPropEquipped(def, ped) then return false end

    local variant = getVariantForStage(def, stage, gender)
    if not variant then return false end

    if state.stage == 0 and not state.savedVariant then
        state.savedVariant = captureToggleVariant(def, ped)
    end

    if not applyToggleVariant(def, variant, use4bit) then
        return false
    end

    state.stage = stage
    state.enabled = true

    return true
end

local function buildClothingStatePayload()
    local payload = {}

    for key in pairs(clothingToggleDefinitions) do
        local state = clothingToggleStates[key]
        payload[key] = {
            enabled = state == nil or state.enabled == true,
            stage = state and state.stage or 0,
        }
    end

    return payload
end

local function setClothingVariant(slotKey, stage)
    local def = clothingToggleDefinitions[slotKey]
    if not def or not def.variants then return false, buildClothingStatePayload() end

    local ped = PlayerPedId()
    if not ped or ped == 0 or not DoesEntityExist(ped) then return false, buildClothingStatePayload() end

    local use4bit = is4bitEnabled()
    local state = clothingToggleStates[slotKey]

    if not state then
        state = { enabled = false, stage = 0 }
        clothingToggleStates[slotKey] = state
    end

    local targetStage = tonumber(stage) or 0
    local gender = getPedGender(ped)

    if targetStage <= 0 then
        if def.allowOff ~= false then
            clearToggle(def, state, ped, gender, use4bit)
            state.enabled = false
            state.stage = 0
            if use4bit then sync4bitAppearance() end
            return true, buildClothingStatePayload()
        end

        return false, buildClothingStatePayload()
    end

    if applyVariantStage(def, state, targetStage, ped, gender, use4bit) then
        if use4bit then sync4bitAppearance() end
        return true, buildClothingStatePayload()
    end

    return false, buildClothingStatePayload()
end

local function toggleClothingSlot(slotKey)
    local def = clothingToggleDefinitions[slotKey]
    if not def then return false, buildClothingStatePayload() end

    local ped = PlayerPedId()
    if not ped or ped == 0 or not DoesEntityExist(ped) then return false, buildClothingStatePayload() end

    local gender = getPedGender(ped)
    local use4bit = is4bitEnabled()
    local state = clothingToggleStates[slotKey]

    if not state then
        local startsEnabled = def.genderVariants == nil
        state = { enabled = startsEnabled, stage = 0 }
        clothingToggleStates[slotKey] = state
    end

    if def.variants and #def.variants > 0 then
        local nextStage = advanceVariantStage(def, state, gender)
        local allowOff = def.allowOff ~= false

        if nextStage == 0 then
            if allowOff then
                clearToggle(def, state, ped, gender, use4bit)
                state.enabled = false
                state.stage = 0
            end
        else
            if not applyVariantStage(def, state, nextStage, ped, gender, use4bit) and allowOff then
                clearToggle(def, state, ped, gender, use4bit)
                state.enabled = false
                state.stage = 0
            end
        end

        if use4bit then sync4bitAppearance() end
        return state.enabled, buildClothingStatePayload()
    end

    if state.enabled == true then
        clearToggle(def, state, ped, gender, use4bit)
        state.enabled = false
        state.stage = 0
    else
        local variant = getGenderVariant(def, gender)

        if variant and variant.drawable ~= nil then
            state.savedVariant = captureToggleVariant(def, ped)
            applyToggleVariant(def, variant, use4bit)
        elseif state.savedVariant then
            applyToggleVariant(def, state.savedVariant, use4bit)
            state.savedVariant = nil
        end

        state.enabled = true
    end

    if use4bit then sync4bitAppearance() end
    return state.enabled, buildClothingStatePayload()
end

local function getClothingToggleState()
    return buildClothingStatePayload()
end

local inventoryConfig = type(Config.Inventory) == 'table' and Config.Inventory or {}
local customInventory = type(inventoryConfig.custom) == 'table' and inventoryConfig.custom or {}
local clothingInventorySlots = type(inventoryConfig.clothingSlots) == 'table' and inventoryConfig.clothingSlots or {
    [36] = { kind = 'prop', id = 0 },
    [37] = { kind = 'prop', id = 1 },
    [38] = { kind = 'component', id = 1 },
    [39] = { kind = 'prop', id = 2 },
    [40] = { kind = 'prop', id = 6 },
    [41] = { kind = 'prop', id = 7 },
    [42] = { kind = 'component', id = 7 },
    [43] = { kind = 'component', id = 11 },
    [44] = { kind = 'component', id = 3 },
    [45] = { kind = 'component', id = 8 },
    [46] = { kind = 'component', id = 9 },
    [47] = { kind = 'component', id = 4 },
    [48] = { kind = 'component', id = 6 },
    [49] = { kind = 'component', id = 5 },
    [50] = { kind = 'component', id = 10 },
}
local inventoryUpdateEvent = type(inventoryConfig.updateEvent) == 'string' and inventoryConfig.updateEvent or 'ox_inventory:updateInventory'

local function addComponentTargets(targets, components, gender)
    if type(components) ~= 'table' then return end

    for i = 1, #components do
        local entry = components[i]
        local id = entry and entry.component
        local variant = entry and resolveVariant(entry, gender)

        if id and variant then
            targets[#targets + 1] = {
                kind = 'component',
                id = id,
                drawable = variant.drawable,
                texture = variant.texture,
                collection = variant.collection,
            }
        end
    end
end

local function addPropTargets(targets, props, gender)
    if type(props) ~= 'table' then return end

    for i = 1, #props do
        local entry = props[i]
        local id = entry and entry.prop
        local variant = entry and resolveVariant(entry, gender)

        if id and variant then
            targets[#targets + 1] = {
                kind = 'prop',
                id = id,
                drawable = variant.drawable,
                texture = variant.texture,
                collection = variant.collection,
            }
        end
    end
end

local function buildTargets(ped, itemData, slotData, gender)
    local targets = {}
    local clientData = itemData and itemData.client or nil

    addComponentTargets(targets, clientData and clientData.components, gender)
    addPropTargets(targets, clientData and clientData.props, gender)

    if #targets > 0 then
        return targets
    end

    local metadata = slotData and slotData.metadata or nil
    if not metadata then
        return targets
    end

    addComponentTargets(targets, metadata.components, gender)
    addPropTargets(targets, metadata.props, gender)

    if #targets > 0 then
        return targets
    end

    if metadata.drawable == nil then
        return targets
    end

    if metadata.component ~= nil then
        targets[#targets + 1] = {
            kind = 'component',
            id = metadata.component,
            drawable = metadata.drawable,
            texture = metadata.texture or 0,
            collection = metadata.collection or '',
        }
    elseif metadata.prop ~= nil then
        targets[#targets + 1] = {
            kind = 'prop',
            id = metadata.prop,
            drawable = metadata.drawable,
            texture = metadata.texture or 0,
            collection = metadata.collection or '',
        }
    end

    return targets
end

local function getAppearanceFeatureMap(ped)
    local grantConfig = getAppearanceGrantConfig()
    local resource = grantConfig.resource or Config.Variants.resource
    if GetResourceState(resource) ~= 'started' then return {} end

    local ok, appearance = pcall(function()
        return exports[resource]:getAppearance(ped)
    end)

    if not ok or type(appearance) ~= 'table' or type(appearance.features) ~= 'table' then
        return {}
    end

    local features = {}

    for i = 1, #appearance.features do
        local feature = appearance.features[i]
        if type(feature) == 'table' and type(feature.id) == 'string' and type(feature.values) == 'table' then
            features[feature.id] = feature
        end
    end

    return features
end

local function getComponentSnapshot(ped, featureMap, featureId, componentId)
    local feature = featureMap[featureId]
    local values = feature and feature.values

    if type(values) == 'table' and values.drawable ~= nil then
        return {
            drawable = tonumber(values.drawable) or 0,
            texture = tonumber(values.texture) or 0,
            collection = values.collection or '',
        }
    end

    return {
        drawable = GetPedDrawableVariation(ped, componentId),
        texture = GetPedTextureVariation(ped, componentId),
        collection = '',
    }
end

local function getPropSnapshot(ped, featureMap, featureId, propId)
    local feature = featureMap[featureId]
    local values = feature and feature.values

    if type(values) == 'table' and values.drawable ~= nil then
        return {
            drawable = tonumber(values.drawable) or -1,
            texture = tonumber(values.texture) or 0,
            collection = values.collection or '',
        }
    end

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
    local grantConfig = getAppearanceGrantConfig()
    if grantConfig.skipDefaults ~= true then return false end

    local defaults = Config.Defaults[gender] and Config.Defaults[gender].components
    return defaultMatchesVariant(defaults and defaults[componentId], variant, false)
end

local function shouldSkipPropGrant(propId, variant, gender)
    if not variant or tonumber(variant.drawable) == -1 then
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

local function buildAppearanceClothingItems()
    local grantConfig = getAppearanceGrantConfig()
    if grantConfig.enabled ~= true then return {} end

    local ped = PlayerPedId()
    if not ped or ped == 0 or not DoesEntityExist(ped) then return {} end

    local gender = getPedGender(ped)
    local featureMap = getAppearanceFeatureMap(ped)
    local items = {}
    local torsoVariant

    for i = 1, #(grantConfig.components or {}) do
        local def = grantConfig.components[i]
        local componentId = def.component

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
                        clothingSource = 'appearance_menu',
                        components = {
                            componentMetadata(componentId, variant),
                        },
                    },
                }
            end

            if componentId == 11 and not skipDefault and grantConfig.bundleTorsoWithJackets ~= false then
                local jacketItem = items[#items]
                if jacketItem and jacketItem.item == def.item and torsoVariant then
                    table.insert(jacketItem.metadata.components, 1, componentMetadata(3, torsoVariant))
                end
            end
        end
    end

    for i = 1, #(grantConfig.props or {}) do
        local def = grantConfig.props[i]
        local propId = def.prop

        if propId then
            local variant = getPropSnapshot(ped, featureMap, def.feature or propToFeatureId[propId], propId)

            if not shouldSkipPropGrant(propId, variant, gender) then
                items[#items + 1] = {
                    item = def.item,
                    metadata = {
                        label = formatAppearanceItemLabel(def, variant),
                        image = def.image,
                        clothingSource = 'appearance_menu',
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

local function findShopTypeInTable(value, depth)
    if type(value) ~= 'table' or depth > 4 then return nil end

    local directKeys = {
        'shopType',
        'shop_type',
        'shopTypeId',
        'shop_type_id',
        'shopId',
        'shop_id',
        'storeType',
        'store_type',
        'type',
    }

    for i = 1, #directKeys do
        local direct = value[directKeys[i]]
        if type(direct) == 'string' and direct ~= '' then
            return direct
        end
    end

    local containerKeys = {
        'activeShop',
        'currentShop',
        'shopInfo',
        'shop',
        'store',
    }

    for i = 1, #containerKeys do
        local child = value[containerKeys[i]]
        local found = findShopTypeInTable(child, depth + 1)
        if found then return found end
    end

    return nil
end

local function getCurrent4bitShopType()
    local grantConfig = getAppearanceGrantConfig()
    local resource = grantConfig.resource or Config.Variants.resource
    if GetResourceState(resource) ~= 'started' then return nil end

    local ok, shopInfo = pcall(function()
        return exports[resource]:getShopInfo()
    end)

    if not ok or type(shopInfo) ~= 'table' then return nil end

    return findShopTypeInTable(shopInfo.activeShop or shopInfo, 0)
end

local function shouldGrantForAppearanceHook(hookData)
    local grantConfig = getAppearanceGrantConfig()
    local allowed = grantConfig.allowedShopTypes

    if type(allowed) ~= 'table' or next(allowed) == nil then
        return true
    end

    local hookShopType = findShopTypeInTable(hookData, 0)
    if hookShopType and (allowed[hookShopType] == true or allowed[hookShopType:lower()] == true) then
        return true
    end

    local currentShopType = getCurrent4bitShopType()
    if currentShopType and (allowed[currentShopType] == true or allowed[currentShopType:lower()] == true) then
        return true
    end

    if not hookShopType and not currentShopType then
        return grantConfig.allowUnknownShop == true
    end

    return false
end

local function grantCurrentAppearanceItems(hookData)
    if not shouldGrantForAppearanceHook(hookData) then return false end

    local items = buildAppearanceClothingItems()
    if #items == 0 then return false end

    TriggerServerEvent('cvn-clothingitems:server:addAppearanceItems', items)
    return true
end

local function registerAppearanceItemHooks()
    local grantConfig = getAppearanceGrantConfig()
    if grantConfig.enabled ~= true or appearanceHooksRegistered then return end

    local resource = grantConfig.resource or Config.Variants.resource
    if GetResourceState(resource) ~= 'started' then return end

    local hooks = grantConfig.hooks or { 'onConfirm' }

    for i = 1, #hooks do
        local hookName = hooks[i]

        if type(hookName) == 'string' and hookName ~= '' then
            local ok = pcall(function()
                exports[resource]:addHook(hookName, function(data)
                    CreateThread(function()
                        Wait(grantConfig.captureDelayMs or 0)
                        grantCurrentAppearanceItems(data)
                    end)
                end)
            end)

            appearanceHooksRegistered = appearanceHooksRegistered or ok
        end
    end
end

local function applyItemClothing(itemData, slotData, forceApply)
    local ped = PlayerPedId()
    if not ped or ped == 0 or not DoesEntityExist(ped) then return false end

    local gender = getPedGender(ped)
    local targets = buildTargets(ped, itemData, slotData, gender)
    if #targets == 0 then return false end

    local use4bit = is4bitEnabled()
    local allMatch = not forceApply

    if not forceApply then
        for i = 1, #targets do
            if not targetMatchesPed(ped, targets[i]) then
                allMatch = false
                break
            end
        end
    end

    if allMatch then
        local needsTorsoReset = false

        for i = 1, #targets do
            local target = targets[i]
            applyTarget(ped, getDefaultTarget(target.kind, target.id, gender), use4bit)

            if target.kind == 'component' and target.id == 11 then
                needsTorsoReset = true
            end
        end

        if needsTorsoReset then
            applyTarget(ped, getDefaultTarget('component', 3, gender), use4bit)
        end
    else
        for i = 1, #targets do
            applyTarget(ped, targets[i], use4bit)
        end
    end

    if use4bit then
        sync4bitAppearance()
    end

    return true
end

local function getItemDataFromInventory(itemName)
    if type(itemName) ~= 'string' or itemName == '' then return nil end

    if type(customInventory.getItemData) == 'function' then
        local ok, customItemData = pcall(customInventory.getItemData, itemName)
        if ok and type(customItemData) == 'table' then
            return customItemData
        end
    end

    local ok, itemData = pcall(function()
        return exports.ox_inventory:Items(itemName)
    end)

    if not ok or type(itemData) ~= 'table' then
        return nil
    end

    return itemData
end

local function parseInventoryChange(slotKey, entry, changes)
    if type(customInventory.parseInventoryChange) == 'function' then
        local ok, first, second, third = pcall(customInventory.parseInventoryChange, slotKey, entry, changes)

        if ok then
            if type(first) == 'table' then
                local data = first
                local slotIndex = tonumber(data.slot)
                local parsedEntry = data.entry
                local removed = data.removed == true

                if slotIndex then
                    return slotIndex, parsedEntry, removed
                end
            else
                local slotIndex = tonumber(first)
                if slotIndex then
                    return slotIndex, second, third == true
                end
            end
        end
    end

    local slotIndex = type(entry) == 'table' and entry.slot or tonumber(slotKey)
    if not slotIndex then
        return nil, nil, false
    end

    if type(entry) == 'table' and entry.name then
        return slotIndex, entry, false
    end

    if entry == false then
        return slotIndex, false, true
    end

    return slotIndex, nil, false
end

RegisterNetEvent(Config.ItemUseEvent, function(itemData, slotData)
    applyItemClothing(itemData, slotData, false)
end)

AddEventHandler(inventoryUpdateEvent, function(changes)
    if type(changes) ~= 'table' then return end

    local ped = PlayerPedId()
    if not ped or ped == 0 or not DoesEntityExist(ped) then return end

    local gender = getPedGender(ped)
    local use4bit = is4bitEnabled()

    for slot, entry in pairs(changes) do
        local slotIndex, parsedEntry, removed = parseInventoryChange(slot, entry, changes)
        local slotConfig = slotIndex and clothingInventorySlots[slotIndex] or nil

        if slotConfig then
            if type(parsedEntry) == 'table' and parsedEntry.name then
                local itemData = getItemDataFromInventory(parsedEntry.name)
                local eventName = itemData and itemData.client and itemData.client.event

                if eventName == Config.ItemUseEvent then
                    applyItemClothing(itemData, parsedEntry, true)
                end
            elseif removed then
                applyTarget(ped, getDefaultTarget(slotConfig.kind, slotConfig.id, gender), use4bit)

                -- Removing a jacket from clothing slot should also reset torso defaults.
                if slotIndex == 43 then
                    applyTarget(ped, getDefaultTarget('component', 3, gender), use4bit)
                end

                if use4bit then
                    sync4bitAppearance()
                end
            end
        end
    end
end)

RegisterNetEvent('cvn-clothingitems:client:grantCurrentAppearanceItems', function()
    grantCurrentAppearanceItems()
end)

CreateThread(function()
    local grantConfig = getAppearanceGrantConfig()
    if grantConfig.enabled ~= true then return end

    local resource = grantConfig.resource or Config.Variants.resource

    while GetResourceState(resource) ~= 'started' do
        Wait(1000)
    end

    registerAppearanceItemHooks()
end)

exports('toggleClothingSlot', toggleClothingSlot)
exports('setClothingVariant', setClothingVariant)
exports('getClothingToggleState', getClothingToggleState)
exports('grantCurrentAppearanceItems', grantCurrentAppearanceItems)
