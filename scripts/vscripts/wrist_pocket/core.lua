--[[
    v2.0.0
    https://github.com/FrostSource/hla-custom-wrist-pockets

    This script monitors player actions with wrist pockets to dynamically generate custom holograms
    because for some reason Valve didn't include this behavior themselves...

    Version 2 allows for dynamic holograms via particles. No extra setup is required besides
    placing the `maps/prefabs/custom_wrist_pocket.vmap` prefab in your maps.

    Scripters using an auto initialized script like Scalable Init do not have to use the
    prefab, and can `require"wrist_pocket.core"`, however precaching is still necessary
    which is something the prefab takes care of.

    For best results entities allowed in wrist pockets should have a targetname
    (preferably unique, or at least entities with the same name should have the same model),
    this helps the script find the correct entity.
    If the entity does not have a targetname the script will still do its best to find the
    correct entity with the context information it has.

    ---

    Modifying holograms through Hammer:

    Attributes that can be set with AddAttribute and the following parameter overrides:
    wrist_blue  - Set the hologram color to blue.
    wrist_green - Set the hologram color to green.
    wrist_white - Set the hologram color to white.

    Setting custom transforms with RunScriptCode and the following parameter overrides:
    WristOrigin(x, y, z) - Set the local origin inside the wrist. Otherwise this is dynamically calculated.
    WristAngle(x, y, z)  - Set the local angle the inside the wrist. Very useful for thin props.
    WristScale(x)        - Set the local scale inside the wrist. Otherwise this is dynamically calculated.

    ---

    Debugging print lines are left in but commented out for those that want them.
    They can be taken out without any problem.
]]
require "core"

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

---If true the script will create holograms for unregistered models using custom particles.
---This is a V2 option that allows custom wrist holograms without any extra setup.
local USE_PARTICLE_FOR_UNREGISTERED = false

---If true the script will periodically update any wrist icons to use the transforms
---defined in their VMDL or through hammer. The think is needed because the game will
--- parent/unparent the icon and change its local transform depending on player interaction.
local UPDATE_ICONS_WITH_THINK = true

---Seconds between each update.
local UPDATE_INTERVAL = 0

local function createIconData()
    return {
        ---Ent handle of the wrist icon.
        ---@type EntityHandle
        handle = nil,

        ---Cached offset relative to wrist.
        ---@type Vector
        origin = nil,

        ---Cached angle relative to wrist.
        ---This is vector instead of qangle because qangle cannot be retrieved from attachment.
        ---@type Vector
        angle = nil,

        ---The scale the game defines for wrist pocket icons (about 0.2)
        ---@type number
        original_scale = nil,

        ---Scale of the icon inside the wrist pocket.
        ---This is the same as `original_scale` unless the model is very large/small.
        ---@type number
        scale = nil,

        ---Index of the created particle.
        ---@type integer
        particle = nil,

        ---If the holo icon should update at next tick.
        ---@type boolean
        should_update = false,
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
---@param force? boolean
---@return number
local function UpdateWristOffset(_, force)
    for i = 1, #StoredIconData do
        local icon = StoredIconData[i].handle
        -- If the icon has a move parent then it is attached to wrist,
        -- otherwise it is probably moving to the hand for a grab.
        if IsValidEntity(icon) then
            -- Particle needs to be updated regardless of parent
            if StoredIconData[i].particle then
                local s = icon:GetAbsScale()
                ParticleManager:SetParticleControl(StoredIconData[i].particle, 2, Vector(s,s,s))
            end
            if StoredIconData[i].should_update or force then
                if icon:GetMoveParent() ~= nil then
                    icon:SetLocalScale(StoredIconData[i].scale)
                    -- Transform attaching origins to entity space so we're working with
                    -- original values defined in ModelDoc.
                    icon:SetLocalOrigin(StoredIconData[i].origin)
                    -- icon needs to be flipped if in right wrist.
                    local local_angle = StoredIconData[i].angle
                    icon:SetLocalAngles(local_angle.x ,local_angle.y + (i == 2 and 180 or 0), local_angle.z)
                    --print('update', icon:GetModelName(),local_angle.x,local_angle.y,local_angle.z)

                    StoredIconData[i].should_update = false
                    -- print("Updating icon, should no longer update", icon:GetAbsScale())
                end
            elseif icon:GetMoveParent() == nil then
                StoredIconData[i].should_update = true
                -- print("Icon should update when idle")
            end
        end
    end
    return UPDATE_INTERVAL
end

---@type CPhysicsProp
local last_released
---@type CPropVRHand
local last_opposite
---Event listener for item_released. Tracks which object is being dropped.
---@param data PLAYER_EVENT_ITEM_RELEASED
local function ItemReleased(data)
    last_released = data.item--[[@as CPhysicsProp]]
    last_opposite = data.hand_opposite
    -- prints("Player drop", data.item_name, data.item, data.item:GetModelName(), "from "..(data.hand:GetHandID() == 0 and "left" or "right").." hand")
end
RegisterPlayerEventCallback("item_released", ItemReleased)
-- ListenToGameEvent("item_released", ItemReleased, nil)

---Calculates the transforms for the icon.
---Only needs to be done once when it's first stored.
---@param wrist_id integer
---@param icon EntityHandle
---@param model_ent CPhysicsProp
local function SetWristIconTransforms(wrist_id, icon, model_ent)

    -- Reset scale to get proper transformed positions, returned at end of function
    local icon_scale = icon:GetLocalScale()
    icon:SetLocalScale(1)

    local scale_multiplier = model_ent:WristScale()
    if not scale_multiplier then
        -- Additional scaling for models too big or small
        local biggest_bound = model_ent:GetBiggestBounding()
        if biggest_bound < 3 or biggest_bound > 10 then
            -- 10 here is the size we're trying to get to
            -- print("Using dynamic scale")
            scale_multiplier = (10 / biggest_bound)
        else
            -- print("Using default scale")
            scale_multiplier = 1
        end
    end

    local local_origin = model_ent:WristOrigin()
    if not local_origin then
        local origin_index = icon:ScriptLookupAttachment("wrist_origin")
        if origin_index > 0 then
            local_origin = icon:TransformPointWorldToEntity(icon:GetAttachmentOrigin(origin_index))
        else
            -- Try to center it dynamically
            local_origin = model_ent:TransformPointWorldToEntity(model_ent:GetCenter())
        end
    end

    local local_angle = model_ent:WristAngle()
    if not local_angle then
        local angle_index = icon:ScriptLookupAttachment("wrist_angle")
        if angle_index > 0 then
            local_angle = icon:TransformPointWorldToEntity(icon:GetAttachmentOrigin(angle_index))
        else
            local_angle = Vector()
        end
    end

    StoredIconData[wrist_id].handle = icon
    StoredIconData[wrist_id].scale = icon_scale * scale_multiplier
    StoredIconData[wrist_id].origin = (-local_origin) * StoredIconData[wrist_id].scale
    StoredIconData[wrist_id].angle = local_angle
    StoredIconData[wrist_id].original_scale = icon_scale
    StoredIconData[wrist_id].should_update = true
    -- Debug.PrintTable(StoredIconData[wristId])

    icon:SaveEntity("wrist_entity", model_ent)
    icon:SetLocalScale(icon_scale)

    -- Icon plays an animation so we should update afterwards
    local delay = Convars:GetFloat("vr_hand_item_holder_insert_delay")
    local duration = Convars:GetFloat("vr_hand_item_holder_insert_duration")
    Player:SetContextThink(DoUniqueString(""),function()
        StoredIconData[wrist_id].should_update = true
    end, delay + duration)
end

---Create a particle matching `model_entity` attached to `icon`.
---@param icon EntityHandle
---@param model_entity EntityHandle
---@param color? "wrist_orange"|"wrist_white"|"wrist_blue"|"wrist_green"
---@return integer
local function createWristParticle(icon, model_entity, color)
    local name = "particles/wrist_pocket/wrist_holo_orange.vpcf"
    if color == "wrist_white" then name = "particles/wrist_pocket/wrist_holo_white.vpcf"
    elseif color == "wrist_green" then name = "particles/wrist_pocket/wrist_holo_green.vpcf"
    elseif color == "wrist_blue" then name = "particles/wrist_pocket/wrist_holo_blue.vpcf"
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
    -- print("Attempting to store model: "..data.item:GetModelName())

    if vlua.find(IgnoredModels, data.item:GetModelName()) then
        return
    end

    -- This code needs to be delayed slightly because for some reason the holo model
    -- doesn't exist by the time this event is fired.
    -- Not sure what errors could pop up by a delayed response besides entity
    -- suddenly being killed. Also not sure how long the delay needs to be.
    Player:SetContextThink(DoUniqueString(""),function()
        local item_holder = last_opposite:GetFirstChildWithClassname("hlvr_hand_item_holder")
        if item_holder == nil then return end
        -- Debug.PrintEntityList(last_hand:GetChildren())
        local icon = item_holder:GetFirstChildWithClassname("baseanimating")
        if icon == nil then return end
        -- The reflex is a version of the model that can only be seen when looking through
        -- the wrist reflex circle and only exists for a short time.
        -- For custom models this reflex is just killed instead of replaced in order to
        -- keep custom models easier to create. This behaviour can be changed if desired.
        local reflex = last_released:GetFirstChildWithClassname("basemodelentity")
        if reflex then reflex:Kill() end

        local wrist_id = last_opposite:GetHandID() + 1
        icon:SetEntityName("__stored_wrist_model_"..wrist_id)

        if USE_BASE_MODEL then
            -- This line uses the prop model directly.
            icon:SetModel(last_released:GetModelName())
            -- print("Using base model")
        else
            -- Using custom holo model.
            if vlua.find(RegisteredModels, last_released:GetModelName()) then
                local replace_model = "models/custom_wrist_pocket" .. last_released:GetModelName():sub(7, -6) .. "_icon.vmdl"
                -- print("Replacing wrist icon with", replace_model)
                icon:SetModel(replace_model)

            elseif USE_PARTICLE_FOR_UNREGISTERED then
                -- NOTE: For some reason the particle will not appear on stored props
                --       after a game load, so as a work around I am creating a matching
                --       proxy prop which needs to be killed later.
                --       If you have any idea why this happens please let me know.
                local pt_model = SpawnEntityFromTableSynchronous("prop_dynamic_override",{
                    targetname="__wrist_particle_model_"..wrist_id,
                    model = last_released:GetModelName(),
                    rendermode = "kRenderNone",
                    disableshadows = "1",
                    solid = "0",
                })
                pt_model:SetAbsScale(0.01)
                -- Setting as parent means it should be killed automatically
                pt_model:SetParent(icon, "")
                StoredIconData[wrist_id].particle = createWristParticle(icon, pt_model, last_released:WristColor())
                icon:SaveEntity("wrist_particle_model",pt_model)
                icon:SetRenderAlpha(0)

            elseif USE_BASE_MODEL_FOR_UNREGISTERED then
                -- print("Using base model because unregistered", last_released:GetModelName())
                icon:SetModel(last_released:GetModelName())

            else
                -- print("Model is not registered", last_released:GetModelName())
                return
            end
            SetWristIconTransforms(wrist_id, icon, last_released)
            UpdateWristOffset()
        end
    -- Function delay, 0.1 is fast enough to not notice a switch.
    end, 0.1)
end
RegisterPlayerEventCallback("player_stored_item_in_itemholder", PlayerStoredItemInItemHolder)

---Auto called by engine for caching. Automatically caches all wrist pocket models.
---@param context CScriptPrecacheContext
local function WristPrecache(context)
    PrecacheResource("model_folder", "models/custom_wrist_pocket", context)
    PrecacheResource("particle_folder", "particles/wrist_pocket", context)
end

RegisterPlayerEventCallback("player_activate", function(data)
    ---@cast data PLAYER_EVENT_PLAYER_ACTIVATE
    if UPDATE_ICONS_WITH_THINK then
        Player:SetThink(UpdateWristOffset, "UpdateWristOffsetThink", UPDATE_INTERVAL)
    end

    -- On game load recalculate the icon transforms.
    if data.game_loaded then
        for i = 1, 2 do
            local icon = Entities:FindByName(nil, "__stored_wrist_model_"..i)
            if icon then
                local stored_ent = icon:LoadEntity("wrist_entity", nil)--[[@as CPhysicsProp]]
                local particle_ent = icon:LoadEntity("wrist_particle_model", nil)
                if stored_ent then
                    if particle_ent then
                        StoredIconData[i].particle = createWristParticle(icon, particle_ent, stored_ent:WristColor())
                    end
                    SetWristIconTransforms(i, icon, stored_ent)
                end
            end
        end
    end
end)




local g = _G

---Gets or sets the wrist origin for this prop.
---If no params are supplied then this works as a getter.
---@param x? number|Vector # Default is 0
---@param y? number # Default is 0
---@param z? number # Default is 0
---@return nil
---@overload fun(self, origin: Vector)
---@overload fun(self): Vector?
function CPhysicsProp:WristOrigin(x, y, z)
    if x then
        if type(x) == "number" then
            x = Vector(x, y or 0, z or 0)
        end
        self:SaveVector("wrist_origin", x)
    else
        ---@diagnostic disable-next-line: return-type-mismatch
        return self:LoadVector("wrist_origin", nil)
    end
end
g.WristOrigin = function(x, y, z)
    getfenv(2).thisEntity:WristOrigin(x, y, z)
end

---Gets or sets the wrist angle for this prop.
---If no params are supplied then this works as a getter.
---@param x? number|Vector # Default is 0
---@param y? number # Default is 0
---@param z? number # Default is 0
---@return nil
---@overload fun(self, angle: Vector)
---@overload fun(self): Vector?
function CPhysicsProp:WristAngle(x, y, z)
    if x then
        if type(x) == "number" then
            x = Vector(x, y or 0, z or 0)
        end
        self:SaveVector("wrist_angle", x)
    else
        ---@diagnostic disable-next-line: return-type-mismatch
        return self:LoadVector("wrist_angle", nil)
    end
end
g.WristAngle = function(x, y, z)
    getfenv(2).thisEntity:WristAngle(x, y, z)
end

---Gets or sets the wrist scale for this prop.
---If no params are supplied then this works as a getter.
---@param x? number # Default is 1
---@return nil
---@overload fun(self): number?
function CPhysicsProp:WristScale(x)
    if x then
        self:SaveNumber("wrist_scale", x)
    else
        ---@diagnostic disable-next-line: return-type-mismatch
        return self:LoadNumber("wrist_scale", nil)
    end
end
g.WristScale = function(x)
    getfenv(2).thisEntity:WristScale(x)
end

---Gets or sets the wrist scale for this prop.
---If no params are supplied then this works as a getter.
---@param color? "wrist_orange"|"wrist_white"|"wrist_blue"|"wrist_green" # Default is "wrist_orange"
---@return nil
---@overload fun(self): string
function CPhysicsProp:WristColor(color)
    if color then
        if color == "wrist_orange" then
            self:DeleteAttribute("wrist_white")
            self:DeleteAttribute("wrist_blue")
            self:DeleteAttribute("wrist_green")
            return
        elseif color == "wrist_white" then
            self:DeleteAttribute("wrist_blue")
            self:DeleteAttribute("wrist_green")
        elseif color == "wrist_blue" then
            self:DeleteAttribute("wrist_white")
            self:DeleteAttribute("wrist_green")
        elseif color == "wrist_green" then
            self:DeleteAttribute("wrist_blue")
            self:DeleteAttribute("wrist_white")
        end
        self:Attribute_SetIntValue(color, 1)
    else
        ---@diagnostic disable: return-type-mismatch
        if self:Attribute_GetIntValue("wrist_white", 0) == 1 then return "wrist_white"
        elseif self:Attribute_GetIntValue("wrist_blue", 0) == 1 then return "wrist_blue"
        elseif self:Attribute_GetIntValue("wrist_green", 0) == 1 then return "wrist_green"
        else return "wrist_orange"
        end
        ---@diagnostic enable: return-type-mismatch
    end
end
g.WristColor = function(x)
    getfenv(2).thisEntity:WristColor(x)
end




return WristPrecache