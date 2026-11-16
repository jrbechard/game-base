# Base changelog

Newest first. One entry per upgrade of the base: what changed, which game it came from, and whether games started earlier need to pull it (`tools/sync_with_base.ps1 -Direction ToGame`).

## 2026-11-17: grid cursor, hold-delay setting, more gameplay buttons

From Picrops' puzzle screen (step 5d).
- **`Logic_Grid_Cursor`** (new): a cursor on a grid of cells. One step on a press, a wait, then repeats while held; a held direction stops at an edge and only a fresh press wraps. Used for puzzle grids, inventories, editors.
- **`hold_delay` setting** (new, `State_Settings`, a 0 to 1 slider, default 0.5 = the old 0.35 s) with a slider on the settings screen. `Logic_Stick_Repeat.delay_for_setting` turns it into seconds and the input router applies it to menu repeat; a grid cursor applies it too. `Logic_Stick_Repeat` also remembers whether its last fire was a fresh press (`last_fire_was_fresh`).
- **Input sources** gained `mark` (top button), `alt_interact` (left button), `count` and `alt_count` (shoulders); positional, so they sit in the same place on every pad. A game that does not use them ignores them.
- New tests: `Tests/test_grid_cursor.gd`. `ui_translations.csv` (a PATTERN file, copied by hand) gained `ui_hold_delay`.
Games started earlier: pull with `-Direction ToGame`, then add the `ui_hold_delay` row to the game's `ui_translations.csv` by hand and run the game's tests.

## 2026-11-16: game-only files no longer raise false drift alarms

Found while building Picrops' puzzle code: new game-only files in a shared folder (`Scripts/Logic/`) showed up as "new reusable files". The drift tools now support exclusions. Each game lists its own game-only files in `tools/game_exclusions.txt` (one pattern per line), and `new_game.ps1` creates that file. The base's own list also accepts `!` exclusion lines. Games started earlier: pull the tools (`-Direction ToGame`) and add a `tools/game_exclusions.txt`.


## 2026-11-16: debug scenes read their lists from the data

`debug_audio_test` now lists every non-music cue from the data, and `debug_rumble_cues` lists every rumble effect and item from the data, so no debug scene names a particular game's sounds or items. Found when syncing the base back into Picrops: a hard-coded cue list would have removed Picrops' own cue buttons. Games started earlier: pull with `-Direction ToGame` (debug_rumble_cues is a worked-example file, so copy it by hand).


## 2026-11-16: first extraction, from Picrops

The base was extracted from Picrops at the end of its build step 4 (input and UI base). It contains:

- project skeleton, event bus, data layer pattern, save (JSON, autosave, backup), progress example
- input router, Nintendo A/B swap, stick repeat, gameplay input sources
- focus navigator (layout driven; sliders and choosers), hover effect, `UI_Animator` with presets
- rumble (data cues from bus events), audio (buses by name, SFX, music, data cues), settings and the settings screen
- shared helpers: `Logic_Bus_Trigger`, `Logic_Json_File`, `Logic_Audio_Buses`
- GUT 9.7.1 and 157 tests, plus debug scenes for the hardware and ear checks

Picrops-only parts (puzzles, locks, farm, its items and cues) were left out; two example items, one rumble cue and one sound cue remain as worked examples.
