--[[
    v1.0.0
    https://github.com/FrostSource/hla-custom-wrist-pockets

    Script for `maps/prefabs/custom_wrist_pocket.vmap`.
]]
local p = require'wrist_pocket.core'

RegisterWristModels({
    -- Add your models here...
})

function Precache(context)
    p(context)
end
