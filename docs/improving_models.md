# Improving Hologram Models

Due to the way the hologram shader works, low detail and flat models can be hard to distinguish between when in the wrist pocket. The floppy disk used in [Creating Hologram Models](hologram_creation.md) is an example of this:

![flat_unmodified_icon](img/flat_unmodified_icon.png)

By modifying the mesh in Hammer or modelling software and adding some more basic geometry you can make the item more recognizable:

![detailed_modified_icon](img/detailed_modified_icon.png)

Timelapse example of this in Hammer:

https://user-images.githubusercontent.com/24839375/139596266-c172c636-f4fc-4ba3-a4fa-e4b51c9b1ce4.mp4

## Improving Hologram Material

`Vr Wireframe Hologram` allows you to define the edges that should be highlighted using a grayscale mask for the color texture. If you have experience modifying/creating textures then this can be a simple way to add detail highlights.

An example of this with Valve's keycard hologram. Left is with a custom material and right is without:

![highlight_hologram](img/highlight_hologram.png)

Which uses this color texture:

![keycard_hologram_highlight](img/keycard_hologram_highlight.png)
