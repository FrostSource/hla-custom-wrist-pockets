local precache = require "wrist_pocket.core"

RegisterWristModels({
    -- Add your models here...
})

---Auto called by engine for caching. Automatically caches all wrist pocket models.
---@param context CScriptPrecacheContext
function Precache(context)
    precache(context)
end