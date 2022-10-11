--[[
    v1.0.0
    https://github.com/FrostSource/hla-custom-wrist-pockets

    Script for `maps/prefabs/custom_wrist_pocket.vmap`.
]]
local p = require'wrist_pocket.core'
function Precache(context)
    p(context)
end
