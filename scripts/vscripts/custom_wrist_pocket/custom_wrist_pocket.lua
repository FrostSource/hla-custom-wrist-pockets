
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
RegisteredModels = RegisteredModels or {
    -- The health pen has a custom holo model so it can be centered.
    "models/weapons/vr_alyxhealth/vr_health_pen.vmdl",
}

---List of models that should be ignored by the script when placed
---inside a wrist pocket. Usually just base game items.
---@type string[]
IgnoredModels = IgnoredModels or {
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
---@type boolean
UseBaseModel = UseBaseModel or false

---If true the script will use the exact model of the item dropped into the wrist pocket
---only if it does not have a registered holo model.
---@type boolean
UseBaseModelForUnregistered = UseBaseModelForUnregistered or false

---If true the script will periodically update any wrist icons to use the origin/angle
---defined in their VMDL. The think is needed because the game will parent/unparent
---the icon and change its local transform depending on player interaction.
---@type boolean
local UPDATE_ICONS_WITH_THINK = true

---@type table[]
StoredIcon = StoredIcon or {
    {
        handle = nil,
        origin = nil,
        angle = nil,
        scale = nil
    },
    {
        handle = nil,
        origin = nil,
        angle = nil,
        scale = nil
    }
}

local UPDATE_INTERVAL = 0

----@type table<string,CBaseEntity|table<integer,table<string,CBaseEntity|table>>>
---@type table<string,any>
Player = Player or {
    ---@type CBaseEntity
    handle = nil,
    ---@type CBaseEntity
    hmd = nil,
    ---@type table[]
    hands = {
        {
            ---@type CBaseEntity
            handle = nil,
            ---@type table
            item_released = {},
        },
        {
            ---@type CBaseEntity
            handle = nil,
            ---@type table
            item_released = {},
        },
    },
}

--#region Utility functions

---Gets the first child in handle hierarchy with a given classname.
---@param handle CBaseEntity
---@param classname string
---@return EntityHandle
local function findChildByClassname(handle, classname)
    for _,child in ipairs(handle:GetChildren()) do
        if child:GetClassname() == classname then
            return child
        end
    end
end

---Converts vr_tip_attachment [1,2] into a hand id [0,1] taking into account left handedness.
---@param vr_tip_attachment "1"|"2"
---@return "0"|"1"
local function getHandIdFromTip(vr_tip_attachment)
    local handId = vr_tip_attachment - 1
    if not Convars:GetBool("hlvr_left_hand_primary") then
        handId = 1 - handId
    end
    return handId
end

--#endregion

---Registers a list of model path strings that have related holo models for the wrist pocket.
---Must be base model paths, NOT holo model paths.
---@param model_list string[]
function thisEntity:RegisterModels(model_list)
    RegisteredModels = vlua.extend(RegisteredModels, model_list)
end

---Ignores a list of model path strings that have related holo models for the wrist pocket.
---Must be base model paths, NOT holo model paths.
---@param model_list string[]
function thisEntity:IgnoreModels(model_list)
    IgnoredModels = vlua.extend(IgnoredModels, model_list)
end

---Updates the wrist icons transforms to the values defined in ModelDoc
---using attachments "wrist_origin" and "wrist_angle".
---@return number
local function UpdateWristOffset()
    for i = 1, #StoredIcon do
        local icon = StoredIcon[i].handle
        local local_origin = StoredIcon[i].origin
        local local_angle = StoredIcon[i].angle
        local local_scale = StoredIcon[i].scale
        -- If the icon has a move parent then it is attached to wrist,
        -- otherwise it is probably moving to the hand for a grab.
        if IsValidEntity(icon) and icon:GetMoveParent() ~= nil then
            -- Transform attaching origins to entity space so we're working with
            -- original values defined in ModelDoc.
            icon:SetLocalOrigin(local_origin * local_scale)
            -- icon needs to be flipped if in right wrist.
            icon:SetLocalAngles(local_angle.x ,local_angle.y + (i == 2 and 180 or 0), local_angle.z)
            --print('update', icon:GetModelName(),local_angle.x,local_angle.y,local_angle.z)
        end
    end
    return UPDATE_INTERVAL
end

---Event listener for item_released. Tracks which object is being dropped.
---@param _ unknown # This is either a reference to thisEntity or the function itself.
---@param data table # Contains information about the entity dropped.
local function ItemReleased(_, data)
    if data.vr_tip_attachment == nil then return end
    -- 1=primary,2=secondary converted to 0=left,1=right
    local handId = getHandIdFromTip(data.vr_tip_attachment)
    local hand_releasing = Player.hands[handId + 1]
    local hand_opposite = Player.hands[(1 - handId) + 1]
    local ent_held
    -- Attempting to find the exact entity dropped.
    -- Any ideas for improvements in this area are appreciated.
    if data.item_name ~= "" then
        local found_ents = Entities:FindAllByName(data.item_name)
        -- If only one with this name exists then we can get the exact handle.
        if #found_ents == 1 then
            ent_held = found_ents[1]
        else
            -- If multiple exist then we need to estimate the entity that was grabbed.
            ent_held = Entities:FindByNameNearest(data.item_name, hand_releasing.handle:GetOrigin(), 128)
        end
    else
        -- Entity without name (hopefully doesn't happen) is found by nearest class type.
        ent_held = Entities:FindByClassnameNearest(data.item, hand_releasing.handle:GetOrigin(), 128)
    end
    hand_releasing.item_released = { ent_held, data.item_name, data.item }
    -- If the item being dropped was in the opposite hand we can assume it isn't anymore.
    if hand_opposite.item_released[1] == hand_releasing.item_released[1] then
        hand_opposite.item_released = {}
        print("Item", data.item_name, ent_held, "no longer in "..(handId == 1 and "left" or "right").." hand")
    end
    print("Player drop", data.item_name, ent_held, "from "..(handId == 0 and "left" or "right").." hand")
end

---Event listener for player_stored_item_in_itemholder. Performs the actual model swapping.
---This event is fired after item_released so temporary caching is used to keep track of object held.
---@param _ unknown # This is either a reference to thisEntity or the function itself.
---@param data table # Contains information about the entity being stored in wrist.
local function PlayerStoredItemInItemHolder(_, data)
    -- Wrist is always opposite to hand that dropped.
    local entity_stored, hand_stored, wristId
    if Player.hands[1].item_released[2] == data.item_name and Player.hands[1].item_released[3] == data.item then
        entity_stored = Player.hands[1].item_released[1]
        hand_stored = Player.hands[2].handle
        wristId = 2
        Player.hands[1].item_released = {}
        print("Stored \""..data.item_name.."\" ["..tostring(entity_stored).."] in right wrist")
    elseif Player.hands[2].item_released[2] == data.item_name and Player.hands[2].item_released[3] == data.item then
        entity_stored = Player.hands[2].item_released[1]
        hand_stored = Player.hands[1].handle
        wristId = 1
        Player.hands[2].item_released = {}
        print("Stored \""..data.item_name.."\" ["..tostring(entity_stored).."] in left wrist")
    else
        print("\""..data.item_name.."\" ["..tostring(entity_stored).."] did not match any released object for some reason!")
        return
    end

    -- Ignored models don't have any manipulation done to them so we can exit early.
    if vlua.find(IgnoredModels, entity_stored:GetModelName()) then
        print("Model in wrist is set to ignored: "..entity_stored:GetModelName())
        return
    end

    print("Attempting to store model: "..entity_stored:GetModelName())

    -- This code needs to be delayed slightly because for some reason the holo model
    -- doesn't exist by the time this event is fired.
    -- Not sure what errors could pop up by a delayed response besides entity
    -- suddenly being killed. Also not sure how long the delay needs to be.
    thisEntity:SetContextThink(DoUniqueString(""),function()
        local item_holder = findChildByClassname(hand_stored, "hlvr_hand_item_holder")
        local icon = findChildByClassname(item_holder, "baseanimating")
        -- The reflex is a version of the model that can only be seen when looking through
        -- the wrist reflex circle and only exists for a short time.
        -- For custom models this reflex is just killed instead of replaced in order to
        -- keep custom models easier to create. This behaviour can be changed if desired.
        local reflex = findChildByClassname(entity_stored, "basemodelentity")
        if reflex then reflex:Kill() end
        icon:SetEntityName("__stored_wrist_model_"..wristId)

        if UseBaseModel then
            -- This line uses the prop model directly.
            icon:SetModel(entity_stored:GetModelName())
        else
            -- Using custom holo model.
            if vlua.find(RegisteredModels, entity_stored:GetModelName()) then
                local replace_model = "models/custom_wrist_pocket" .. entity_stored:GetModelName():sub(7, -6) .. "_icon.vmdl"
                print("Replacing wrist icon with", replace_model)
                icon:SetModel(replace_model)
            elseif UseBaseModelForUnregistered then
                print("Using base model", entity_stored:GetModelName())
                icon:SetModel(entity_stored:GetModelName())
            else
                print("Model is not registered", entity_stored:GetModelName())
                return
            end
            SetWristIconOffsets(wristId, icon)
            UpdateWristOffset()
        end
    -- Function delay, 0.1 is fast enough to not notice a switch.
    end, 0.1)
end

function SetWristIconOffsets(wristId, icon)
    local prev_scale = icon:GetLocalScale()
    icon:SetLocalScale(1)
    local attach_origin = icon:GetAttachmentOrigin(icon:ScriptLookupAttachment("wrist_origin"))
    local attach_angle = icon:GetAttachmentOrigin(icon:ScriptLookupAttachment("wrist_angle"))
    local local_origin = icon:TransformPointWorldToEntity(attach_origin)
    local local_angle = icon:TransformPointWorldToEntity(attach_angle)
    StoredIcon[wristId].handle = icon
    StoredIcon[wristId].origin = -local_origin
    StoredIcon[wristId].angle = local_angle
    StoredIcon[wristId].scale = prev_scale
    icon:SetLocalScale(prev_scale)
end

---Auto called by engine for caching. Automatically caches all wrist pocket models.
---@param context CScriptPrecacheContext
function Precache(context)
    PrecacheResource("model_folder", "models/custom_wrist_pocket", context)
end

---Updates the player table with handles pointing to existing player objects.
local function UpdatePlayer()
    Player.handle = Entities:GetLocalPlayer()
    Player.hmd = Player.handle:GetHMDAvatar()
    Player.hands[1].handle = Player.hmd:GetVRHand(0)
    Player.hands[2].handle = Player.hmd:GetVRHand(1)
    print("Player table updated...")
end

---Called when player entity should definitely exist the game.
---Sets up prop listeners and initial player handles.
local function PlayerSpawn()
    print("Player spawned...")
    StopListeningToAllGameEvents(thisEntity)
    UpdatePlayer()
    ListenToGameEvent("player_stored_item_in_itemholder", PlayerStoredItemInItemHolder, thisEntity)
    ListenToGameEvent("item_released", ItemReleased, thisEntity)
end

---Auto called by engine on entity activate (after spawn).
---@param activateType "0"|"1"|"2"
function Activate(activateType)
    -- Player doesn't exit at time of Activate, delay the function for a bit.
    thisEntity:SetContextThink("plrspawn", PlayerSpawn, 0.01)
    if UPDATE_ICONS_WITH_THINK then
        thisEntity:SetThink(UpdateWristOffset, "UpdateWristOffsetThink", UPDATE_INTERVAL)
    end
    -- On game load reset the icon offsets.
    if activateType == 2 then
        for i = 1, 2 do
            local icon = Entities:FindByName(nil, "__stored_wrist_model_"..i)
            print(icon)
            if icon then
                SetWristIconOffsets(i, icon)
            end
        end
    end
end
