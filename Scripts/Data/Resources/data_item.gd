class_name Data_Item
extends Data_Base
## === One item: the worked example of a data type ===
## Copy this pattern for each kind of authored data (see generate_items.gd and
## Global_Manager_GameData). Replace the kinds with whatever the game needs.

## KEY unlocks something in the world; BOOST permanently raises something;
## TOOL is used on things in the world.
enum Kind { KEY, BOOST, TOOL }

@export var kind: Kind = Kind.KEY
## Filled in when item art exists (Assets/Sprites/Items).
@export var icon: Texture2D
