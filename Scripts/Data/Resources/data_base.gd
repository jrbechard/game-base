class_name Data_Base
extends Resource
## === Shared fields for every authored Data_ resource ===
## Why: id and name logic is written once; item, level, place and other types extend this.
## Authored data is read-only at runtime; changing game state lives in State_.

## Readable id other data refers to (e.g. &"example_tool"); survives sheet reordering.
@export var id: StringName
## Row number from the sheet, kept for reading and sorting only.
@export var number: int
## Translation key; call tr(name) for the shown text.
@export var name: String
## English text kept for reading in the inspector.
@export var name_en: String
