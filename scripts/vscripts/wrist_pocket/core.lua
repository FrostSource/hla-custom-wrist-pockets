
--[[
    This script monitors player actions with props to keep track of stored wrist pocket
    items so it can modify the look of them because for some reason Valve didn't include
    this behavior themselves...

    A custom holo model should have its origin exactly the same as the base model,
    ideally an exact copy of the model. If the origin is off center it can be centered
    if the wrist by using the two model attachments the script looks for:
    wrist_origin - Defines the origin the icon should be placed in the wrist relative to the holder.
    wrist_angle  - Defines the angle (use the Relative Origin property, not Relative Angles) the icon should be rotated relative to the holder.

    This script assumes all models reside in the /models/ folder of the root addon directory
    and ends with .vmdl
    And that all hologram models reside in /models/custom_wrist_pocket/ with the rest of
    the path matching the base model path.

    Current naming convention uses a different root folder name with _icon.vmdl appended
    Naming example:
    Base model path: /models/props/interior_deco/tabletop_alarm_clock.vmdl
    Holo model path: /models/custom_wrist_pocket/props/interior_deco/tabletop_alarm_clock_icon.vmdl

    All models inside /models/custom_wrist_pocket_models/ are precached by this script.

    For best results entities allowed in wrist pockets should have a targetname
    (preferably unique, or at least entities with the same name should have the same model),
    this helps the script find the correct entity.
    If the entity does not have a targetname the script will still do its best to find the
    correct entity with the context information it has.

    Debugging print functions are left in for those that want them but can be taken out without any problem.
]]

---List of models registered as having custom holo models. Unregistered models will use
---the default model Valve assigned which is the health pen holo.
---@type string[]
local RegisteredModels = {
    -- The health pen has a custom holo model so it can be centered.
    "models/weapons/vr_alyxhealth/vr_health_pen.vmdl",
}

---List of models that should be ignored by the script when placed
---inside a wrist pocket. Usually just base game items.
---@type string[]
local IgnoredModels = {
    "models/weapons/vr_grenade/grenade.vmdl",
    "models/props/distillery/bottle_vodka.vmdl",
    "models/props/distillery/bottle_vodka_larry.vmdl",
    "models/breakable_props/bottle_o_gin.vmdl",
    "models/props/beer_bottle_1.vmdl",
    "models/props_combine/combine_battery/combine_battery_large.vmdl",
    "models/props_junk/garbage_glassbottle003a.vmdl",
    "models/props_junk/glassbottle01a.vmdl",
    "models/props_combine/health_charger/health_vial.vmdl",
    "models/props/misc/keycard_001.vmdl",
    "models/creatures/headcrab_reviver/reviver_heart.vmdl",
    "models/props/junk/wine_bottle.vmdl",
    "models/weapons/vr_xen_grenade/vr_xen_grenade.vmdl",

    -- Pen is NOT IGNORED because it uses a custom icon to fix it!
    --"models/weapons/vr_alyxhealth/vr_health_pen.vmdl",

    -- I thought these models had built in icons but they don't appear to.
    --"models/props/beer_bottle_1_empty.vmdl",
    --"models/props_combine/combine_battery/combine_battery.vmdl",
    --"models/props_junk/garbage_glassbottle001a.vmdl",
}

---If true the script will use the exact model of the item dropped into the wrist pocket
---even if it is registered.
local USE_BASE_MODEL = false

---If true the script will use the exact model of the item dropped into the wrist pocket
---only if it does not have a registered holo model.
local USE_BASE_MODEL_FOR_UNREGISTERED = false

local USE_PARTICLE_FOR_UNREGISTERED = true

---If true the script will periodically update any wrist icons to use the origin/angle
---defined in their VMDL. The think is needed because the game will parent/unparent
---the icon and change its local transform depending on player interaction.
local UPDATE_ICONS_WITH_THINK = true

---Seconds between each update.
local UPDATE_INTERVAL = 0

local function createIconData()
    return {
        ---@type EntityHandle
        handle = nil,
        ---Cached offset relative to wrist.
        ---@type Vector
        origin = nil,
        ---Cached angle relative to wrist.
        ---This is vector instead of qangle because qangle cannot be retrieved from attachment.
        ---@type Vector
        angle = nil,
        ---@type number
        scale = nil,
        ---@type integer
        particle = nil,
    }
end

local StoredIconData = {
    createIconData(),
    createIconData()
}

---Registers a list of model path strings that have a matching holo model for the wrist pocket.
---Must be base model paths, NOT holo model paths.
---@param model_list string[]
function RegisterWristModels(model_list)
    RegisteredModels = vlua.extend(RegisteredModels, model_list)
end

---Ignores a list of model path strings that have a matching holo model for the wrist pocket.
---Must be base model paths, NOT holo model paths.
---@param model_list string[]
function IgnoreWristModels(model_list)
    IgnoredModels = vlua.extend(IgnoredModels, model_list)
end

---Updates the wrist icons transforms to the values defined in ModelDoc
---using attachments "wrist_origin" and "wrist_angle".
---@return number
local function UpdateWristOffset()
    for i = 1, #StoredIconData do
        local icon = StoredIconData[i].handle
        local local_origin = StoredIconData[i].origin
        local local_angle = StoredIconData[i].angle
        local local_scale = StoredIconData[i].scale
        -- If the icon has a move parent then it is attached to wrist,
        -- otherwise it is probably moving to the hand for a grab.
        if IsValidEntity(icon) then
            if StoredIconData[i].particle then
                local s = icon:GetAbsScale()
                ParticleManager:SetParticleControl(StoredIconData[i].particle, 2, Vector(s,s,s))
            elseif icon:GetMoveParent() ~= nil then
                -- Transform attaching origins to entity space so we're working with
                -- original values defined in ModelDoc.
                icon:SetLocalOrigin(local_origin * local_scale)
                -- icon needs to be flipped if in right wrist.
                icon:SetLocalAngles(local_angle.x ,local_angle.y + (i == 2 and 180 or 0), local_angle.z)
                --print('update', icon:GetModelName(),local_angle.x,local_angle.y,local_angle.z)
            end
        end
    end
    return UPDATE_INTERVAL
end

---@type EntityHandle
local last_released
---@type CPropVRHand
local last_hand
---@type CPropVRHand
local last_opposite
---Event listener for item_released. Tracks which object is being dropped.
---@param data PLAYER_EVENT_ITEM_RELEASED
local function ItemReleased(data)
    last_released = data.item
    last_hand = data.hand
    last_opposite = data.hand_opposite
    prints("Player drop", data.item_name, data.item, data.item:GetModelName(), "from "..(data.hand:GetHandID() == 0 and "left" or "right").." hand")
end
RegisterPlayerEventCallback("item_released", ItemReleased)
-- ListenToGameEvent("item_released", ItemReleased, nil)

---comment
---@param wristId integer
---@param icon EntityHandle
---@param model_ent EntityHandle
local function SetWristIconOffsets(wristId, icon, model_ent)
    local prev_scale = icon:GetLocalScale()
    icon:SetLocalScale(1)

    local local_origin = Vector()
    local origin_index = icon:ScriptLookupAttachment("wrist_origin")
    if origin_index > 0 then
        local_origin = icon:TransformPointWorldToEntity(icon:GetAttachmentOrigin(origin_index))
    else
        -- Try to center it dynamically
        local_origin = -model_ent:TransformPointWorldToEntity(model_ent:GetCenter())
    end

    local local_angle = Vector()
    local angle_index = icon:ScriptLookupAttachment("wrist_angle")
    if angle_index > 0 then
        local_angle = icon:TransformPointWorldToEntity(icon:GetAttachmentOrigin(angle_index))
    end

    StoredIconData[wristId].handle = icon
    StoredIconData[wristId].origin = -local_origin
    StoredIconData[wristId].angle = local_angle
    StoredIconData[wristId].scale = prev_scale
    icon:SaveEntity("wrist_entity", model_ent)
    icon:SetLocalScale(prev_scale)
end

---comment
---@param icon EntityHandle
---@param model_entity EntityHandle
---@return integer
local function createWristParticle(icon, model_entity)
    local name = "particles/wrist_pocket/wrist_holo.vpcf"
    if model_entity:Attribute_GetIntValue('wrist_white', 0) == 1 then name = "particles/wrist_pocket/wrist_holo_white.vpcf"
    elseif model_entity:Attribute_GetIntValue('wrist_green', 0) == 1 then name = "particles/wrist_pocket/wrist_holo_green.vpcf"
    elseif model_entity:Attribute_GetIntValue('wrist_blue', 0) == 1 then name = "particles/wrist_pocket/wrist_holo_blue.vpcf"
    end
    local pt = ParticleManager:CreateParticle(name, 1, icon)
    ParticleManager:SetParticleControlEnt(pt, 1, model_entity, 0, "", Vector(), false)
    local s = icon:GetAbsScale()
    ParticleManager:SetParticleControl(pt, 2, Vector(s,s,s))
    return pt
end

---Event listener for player_stored_item_in_itemholder. Performs the actual model swapping.
---This event is fired after item_released so temporary caching is used to keep track of object held.
---@param data PLAYER_EVENT_PLAYER_STORED_ITEM_IN_ITEMHOLDER # Contains information about the entity being stored in wrist.
local function PlayerStoredItemInItemHolder(data)
    for key, value in pairs(data) do
        print(key,value)
    end
    print("Attempting to store model: "..data.item:GetModelName())

    -- This code needs to be delayed slightly because for some reason the holo model
    -- doesn't exist by the time this event is fired.
    -- Not sure what errors could pop up by a delayed response besides entity
    -- suddenly being killed. Also not sure how long the delay needs to be.
    Player:SetContextThink(DoUniqueString(""),function()
        print("Doing store")
        local item_holder = last_opposite:GetFirstChildWithClassname("hlvr_hand_item_holder")
        print("item_holder", item_holder)
        if item_holder == nil then return end
        -- Debug.PrintEntityList(last_hand:GetChildren())
        local icon = item_holder:GetFirstChildWithClassname("baseanimating")
        print("icon", icon)
        if icon == nil then return end
        -- The reflex is a version of the model that can only be seen when looking through
        -- the wrist reflex circle and only exists for a short time.
        -- For custom models this reflex is just killed instead of replaced in order to
        -- keep custom models easier to create. This behaviour can be changed if desired.
        local reflex = last_released:GetFirstChildWithClassname("basemodelentity")
        if reflex then reflex:Kill() end

        local wrist_id = last_opposite:GetHandID() + 1
        icon:SetEntityName("__stored_wrist_model_"..wrist_id)
        print("wrist_id", wrist_id)

        if USE_BASE_MODEL then
            -- This line uses the prop model directly.
            icon:SetModel(last_released:GetModelName())
            print("Using base model")
        else
            -- Using custom holo model.
            if vlua.find(RegisteredModels, last_released:GetModelName()) then
                local replace_model = "models/custom_wrist_pocket" .. last_released:GetModelName():sub(7, -6) .. "_icon.vmdl"
                print("Replacing wrist icon with", replace_model)
                icon:SetModel(replace_model)
            elseif USE_PARTICLE_FOR_UNREGISTERED then
                print("Using particle")
                StoredIconData[wrist_id].particle = createWristParticle(icon, last_released)
                icon:SetRenderAlpha(0)
            elseif USE_BASE_MODEL_FOR_UNREGISTERED then
                print("Using base model because unregistered", last_released:GetModelName())
                icon:SetModel(last_released:GetModelName())
            else
                print("Model is not registered", last_released:GetModelName())
                return
            end
            SetWristIconOffsets(wrist_id, icon, last_released)
            UpdateWristOffset()
        end
    -- Function delay, 0.1 is fast enough to not notice a switch.
    end, 0.1)
end
RegisterPlayerEventCallback("player_stored_item_in_itemholder", PlayerStoredItemInItemHolder)

---Auto called by engine for caching. Automatically caches all wrist pocket models.
---@param context CScriptPrecacheContext
local function WristPrecache(context)
    print("Doing wrist precache")
    PrecacheResource("model_folder", "models/custom_wrist_pocket", context)
    PrecacheResource("particle_folder", "particles/wrist_pocket", context)
end

RegisterPlayerEventCallback("player_activate", function(data)
    ---@cast data PLAYER_EVENT_PLAYER_ACTIVATE
    if UPDATE_ICONS_WITH_THINK then
        Player:SetThink(UpdateWristOffset, "UpdateWristOffsetThink", UPDATE_INTERVAL)
    end
    -- On game load reset the icon offsets.
    if data.game_loaded then
        for i = 1, 2 do
            local icon = Entities:FindByName(nil, "__stored_wrist_model_"..i)
            print(icon)
            local ent = icon:LoadEntity("wrist_entity", nil)
            if icon and ent then
                SetWristIconOffsets(i, icon, ent)
            end
        end
    end
end)

return WristPrecache