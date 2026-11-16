class_name Logic_Audio_Buses
extends RefCounted
## === Audio buses by name, never by index ===
## Pogne hard-coded bus numbers (0 to 4), which breaks the moment the order changes.
## Everything here looks a bus up by its name. Buses are built in code, so there is no
## bus-layout file to keep in sync. Master always exists.

const MASTER := &"Master"
const MUSIC := &"Music"
const SFX := &"SFX"
const AMBIENCE := &"Ambience"
const UI := &"UI"
## Buses created on top of Master, each sending to Master.
const BUSES: Array[StringName] = [MUSIC, SFX, AMBIENCE, UI]

const SILENT_DB := -80.0

## Create any missing bus. Safe to call many times.
static func ensure_buses() -> void:
	for bus_name in BUSES:
		if AudioServer.get_bus_index(bus_name) != -1:
			continue
		var index := AudioServer.bus_count
		AudioServer.add_bus(index)
		AudioServer.set_bus_name(index, bus_name)
		AudioServer.set_bus_send(index, MASTER)

static func has_bus(bus_name: StringName) -> bool:
	return AudioServer.get_bus_index(bus_name) != -1

## Set a bus volume from a 0..1 slider value. Returns false (with a warning) for an unknown bus.
static func set_volume(bus_name: StringName, linear: float) -> bool:
	var index := AudioServer.get_bus_index(bus_name)
	if index == -1:
		push_warning("Logic_Audio_Buses: no bus named '%s'" % bus_name)
		return false
	var value := clampf(linear, 0.0, 1.0)
	AudioServer.set_bus_volume_db(index, SILENT_DB if value <= 0.0001 else linear_to_db(value))
	return true

## The bus volume as a 0..1 slider value; 0.0 for an unknown bus.
static func get_volume(bus_name: StringName) -> float:
	var index := AudioServer.get_bus_index(bus_name)
	if index == -1:
		return 0.0
	var db := AudioServer.get_bus_volume_db(index)
	return 0.0 if db <= SILENT_DB + 0.1 else db_to_linear(db)
