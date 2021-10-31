# Creating Hologram Models

A hologram model/icon is the visual representation of the prop stored stored inside the player's wrist. For accurate retrieval (the way it moves to the hand when being grabbed) this model should have the same shape and origin of the base model. The easiest way to do this is to create a new model from the base model in hammer through the right-click context menu:

![Creating holo model](img/create_model_context_menu.png)

We want to make sure to save it in the correct location. The hologram model path must match the base model path within a root directory named `custom_wrist_pocket` with `_icon` appended.

The above floppy disk model is `models/props_discoverable/floppy_disk_download_internet.vmdl` so we save to `models/custom_wrist_pocket/props_discoverable/floppy_disk_download_internet_icon.vmdl`. The script uses this predictable naming scheme to procedurally load the correct model.

Once created we can open the model up inside ModelDoc to add some necessary changes ([if you've never used ModelDoc I recommend reading the wiki pages](https://developer.valvesoftware.com/wiki/Half-Life:_Alyx_Workshop_Tools/Modeling)).

To match the style of the base game the default material must be changed to a hologram style.

## Hologram Material

Add a DefaultMaterialGroup node and search for `wrist hologram` in the material picker. Although the built-in materials are specific to the item they should look fine for a simple model. There are also 3 plain sample materials included in `models/custom_wrist_pocket/materials/` which the example holograms use. For this model I'm choosing `models/custom_wrist_pocket/materials/orange_icon_hologram.vmat`.

## Rotation/Origin

Wrist icons face towards the positive Y axis when rotating towards the player head. The rotation of the base model means it faces the wrong way in-game:

![Bad icon rotation](img/bad_icon_rotation.jpg)
    
To get our desired rotation we can add an attachment called `wrist_angle` to tell the script how to rotate the model in real time:
    
![Wrist angle attachment](img/wrist_angle_attachment.png)

`Relative Origin` should be used for your angles instead of `Relative Angles`. This may seem counter-intuitive but is the current method the script uses to calculate the angle.

### How do we find the correct angle for our model?

Inside Hammer face the camera towards the negative Y axis (away from the green arrow) while looking at your model, then rotate it to face towards the camera. Copy the transform angles to the attachment origin.

![](img/rotate_to_face_y.jpg)

### For models that aren't centered

This model has its origin centered so it doesn't need to be moved, but for models with an off-center origin we can use another attachment named `wrist_origin` which should be placed roughly at the center of the model.

Feel free to examine all sample hologram icons to see how the attachments are used for different models.

# Registering The Hologram Model

See [Creating The Script](script_setup.md#creating_the_script) section of [script_setup.md](script_setup.md) for registering models.
