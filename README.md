# Game base

A starting point for Godot 4.7 games, built from the foundations of Picrops. It gives a new game the systems every game needs, already connected and tested, so a game starts with its own mechanic instead of rebuilding input, saving, audio and menus.

## What you get

- **Project skeleton:** folder layout, a `Main` scene with host layers (screen, overlay, transition, debug), canvas_items stretch at 1920x1080, an empty boot screen.
- **Event bus** (`Global_Manager_Events`): every cross-system event, declared in one place.
- **Data layer:** `Data_Base`, a CSV to `.tres` generator pattern, id lookup in `Global_Manager_GameData`.
- **Save:** one autosaved JSON file with a temp-file swap and a backup (`Global_Manager_Save`, `State_Base`).
- **Input:** keyboard, gamepad and mouse in one router, with the Nintendo A/B swap by pad name, stick repeat, and gameplay input sources.
- **Menus:** focus navigator (layout driven, sliders and choosers), hover effect, one animator (`UI_Animator`) with data presets.
- **Rumble:** data cues fired from bus events, one swappable hardware function.
- **Audio:** buses by name, data cues fired from bus events, SFX and music managers.
- **Settings:** volumes, language, rumble strength, reduce motion, on a ready-made settings screen.
- **Tests:** GUT 9.7.1 and a suite for all of the above, plus debug scenes for the hardware and ear checks.

`docs/SYSTEMS_MAP.md` shows how every piece connects. Read it first.

## Start a new game

From a PowerShell prompt in this folder:

```powershell
.\tools\new_game.ps1 -Name "My Game" -Dest "C:\Users\you\Desktop\my-game"
```

It copies the base, names the project, records which base version it came from, and starts a fresh git repo with a first commit. Then:

1. Open the new folder in Godot once (it imports), and use **Project > Reload Current Project** after any change to the autoload list.
2. Read `CLAUDE.md` and `docs/ARCHITECTURE.md` (they hold the conventions) and fill in `docs/DESIGN.md`.
3. Delete the worked examples you will not use: the two example items and the `item_acquired` events, rumble cue and sound (see "Worked examples" below), then add your own data.
4. Run the tests (below) to confirm the starting point is green.

## Run the tests

```powershell
& "C:\Users\jrbechard\Desktop\Godot\Godot_v4.7-stable_win64.exe" --headless --path . -s addons/gut/gut_cmdln.gd -gexit
```

## Worked examples (delete or replace per game)

| What | Where |
| --- | --- |
| Two example items and their generator | `Data/Items/items.csv`, `Scripts/Data/Generation/generate_items.gd`, `Scripts/Data/Resources/data_item.gd` |
| Granting an item through the bus, and saving it | `Global_Manager_Progress`, `State_Progress`, the `item_*` events in the GAME block of `global_manager_events.gd` |
| A rumble cue and a sound cue fired by an event | `Data/Rumble/item_acquired.tres`, `Data/Audio/Cues/item_acquired.tres` |
| Placeholder sounds (generated tones) | `Assets/Audio/`, made by `Scripts/Tools/tool_generate_placeholder_sounds.gd`; replace with real sound design |

## Keep upgrading the base as you build games

The base is meant to grow with every game. It is the **upstream** for reusable code, and `tools/base_files.txt` lists the files that should match across games.

**While building a game**, any improvement to a reusable system, or a new reusable system, belongs in the base too. Keep base files free of game names (items, levels, enemies); if one needs a game name, split the game part out first.

**At the end of each feature or step**, in the base folder:

```powershell
.\tools\diff_against_base.ps1 -GameDir "C:\Users\you\Desktop\my-game"              # what differs?
.\tools\sync_with_base.ps1    -GameDir "C:\Users\you\Desktop\my-game" -Direction ToBase           # preview
.\tools\sync_with_base.ps1    -GameDir "C:\Users\you\Desktop\my-game" -Direction ToBase -Apply    # copy
```

1. A brand-new reusable file must be added to `tools/base_files.txt` first, or the tools will not see it.
2. Run the base tests (above), add a line to `CHANGELOG.md`, and commit in the base.

**In the other games**, pull the upgrade in the other direction, then run that game's tests:

```powershell
.\tools\sync_with_base.ps1 -GameDir "C:\Users\you\Desktop\other-game" -Direction ToGame -Apply
```

A game keeps its own game-only files (for example puzzle logic that lives in `Scripts/Logic/`) out of the drift report by listing them in its `tools/game_exclusions.txt`, one pattern per line (`*` matches any characters, a trailing `/` means a whole folder).

Sync copies listed files only and never deletes. Files a game edits on purpose (its project file, `main.gd`, the event bus's game block, its data and docs) are not listed, so they are never overwritten. A game's `tools/base_version.txt` records the base commit it started from.

## Notes

- Godot's editor rewrites `.gitignore` and `.gitattributes` when it opens a project. Check `git status` before committing.
- Esc and Space are routed menu keys that the input router consumes; debug scenes read `_input` and quit with F10.
- Godot prints a leak warning at exit when a sound is playing. It comes from the engine and is harmless (see the note in `global_manager_sfx.gd`).
- Rumble on the Switch 2 Pro Controller over USB does nothing under Godot 4.7; the Xbox and original Switch Pro work.
