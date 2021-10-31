# Setting Up The Script

Although the system is set up to be as user friendly for non-scripters as possible, at least one script needs to be modified to register your custom models. This file should be updated whenever you create a new hologram model.

## Creating The Script

Rename `scripts/vscripts/register_models_template.lua` to a unique name that will only exist for your addon so it won't clash with another addon using this system - this example uses `custom_wrist_models_preview_registered.lua`.

The template script contains all the code needed to register models, it just needs a list of your custom icons added.

```lua
function LocalModelRegister(input)
    input.caller:RegisterModels({
        -- Add your models here...
    })
end
```

If we have created hologram icons for the following two base models:

```
models/props/ration_bar.vmdl
models/props/milk_carton_1.vmdl
```

We would add them to the script like so:

```lua
function LocalModelRegister(input)
    input.caller:RegisterModels({
        "models/props/ration_bar.vmdl",
        "models/props/milk_carton_1.vmdl"
    })
end
```

Each path to the base model must be wrapped in quotes (either double `"` or single `'`) and end with a comma if there is another path below it. You are allowed to end every path line with a comma if you wish.

## Adding The Script To Your Map

Add the prefab `maps/prefabs/custom_wrist_pocket.vmap` to every map that should have custom wrist pocket models. Open the prefab properties and add the name of your script to the `Registered Models Script` property:

![](img/adding_script_to_prefab.png)
