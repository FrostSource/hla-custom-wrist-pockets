--[[
    This script exists as an example for how to register your custom hologram models.
    These models are registered for `maps/custom_wrist_models_example.vmap`.

    If you are strictly using dynamically generated holograms then none of this is necessary.
]]
require "wrist_pocket.core"

RegisterWristModels({
    "models/props/interior_deco/tabletop_alarm_clock.vmdl",
    "models/props/ration_bar.vmdl",
    "models/props/milk_carton_1.vmdl",
    "models/props/alyx_hideout/dry_erase_marker_nocap.vmdl",
    "models/weapons/vr_alyxgun/vr_alyxgun_clip.vmdl",
    "models/props_discoverable/floppy_disk_download_internet.vmdl",
    "models/props/junk/figurine_scout.vmdl",
    "models/props/construction/screwdriver_1_b.vmdl",
    "models/props/construction/pliers_02a.vmdl",
    "models/props/choreo_office/gnome.vmdl",
    "models/props_interiors/waterbottle.vmdl",
})

IgnoreWristModels({
    "models/props/interior_deco/tabletop_key01.vmdl",
})