# Base changelog

Newest first. One entry per upgrade of the base: what changed, which game it came from, and whether games started earlier need to pull it (`tools/sync_with_base.ps1 -Direction ToGame`).

## 2026-11-17 (boot flow): save on request, settings over any screen

- **`Global_Manager_Save`**: `save_exists()` (true when a save or its backup is on disk) and it now writes at once on the new bus intent `save_requested`, so leaving to a title or quitting never waits on the autosave timer. New BASE bus events `flow_requested(target)` (the intent screens send to move the game between its big states; the game's flow manager acts on it) and `save_requested`. Tests: `Tests/test_save_requests.gd`.
- **`Shell_Settings.open_over(parent, on_close)`**: opens the settings screen on top of any screen with a plain backdrop; the title, the pause menu and the puzzle pause menu all use it.
- The title menu, the pause menu and `Manager_Flow` stay in the game (their entries are game specific); the base keeps the pieces above. Games started earlier: pull with `-Direction ToGame`.
## 2026-11-17 (CRT overlay): one CRT layer over every screen

- **`Shell_Screen_Effect`** (new): a `Screen_Effect` layer in Main (above screens and overlays, below the transition) draws the CRT shader over whatever screen is showing. Strength is the new `screen_effect` setting (0 = off and the overlay is hidden, 1 = full), set from a slider in the settings screen through the usual bus intent; the look is Ever Blue's in-game one. It stays hidden until `splash_finished` when a splash plays, since the splash has its own CRT. Tests: `Tests/test_screen_effect.gd`. Main's scene and script were edited by hand (Main is not synced). Games started earlier: pull with `-Direction ToGame`, then add the layer to Main like the base's.
## 2026-11-17 (step 7): areas as text, free top-down movement

- **`Logic_Area_Map`** (new): a screen of tiles as text (`#` wall, `.` floor, rows joined with `/`), 60 px tiles so 32 x 18 fills 1920 x 1080; everything outside is solid. **`Logic_Overworld_Move`** (new): free top-down walking against tiles. Each axis moves on its own so a diagonal push slides along a wall, long steps are cut into half-tile pieces so nothing tunnels, `walk_direction` keeps a diagonal no faster than a straight line, and `nearest_in_reach` picks what a press acts on. **`Logic_Csv_Rows`** (new): reads a data sheet into rows, for Generate_ scripts. Tests: `Tests/test_overworld_move.gd`.
- `Global_Manager_Scenes.change_screen` now returns the new screen, and `current_screen()` returns the one showing (backward compatible).
- Debug scenes that instance Main now set `splash = null`, so the company splash does not play in front of them.
Games started earlier: pull with `-Direction ToGame`.
## 2026-11-17 (company splash): the Club Cabanon splash

- **`Shell_Splash`** (new, ported from Pogne): the Club Cabanon logo spins faster and faster with afterimage trails and a rising whoosh, the company sound plays, then a white-out. Any key, pad button or click skips it. It announces the new bus event `splash_finished`; Main opens the first screen then. Set Main's new `splash` export to `shell_splash.tscn` to use it (empty = no splash, so older games keep booting as before). Also new: `Transition_Fade` (reusable full-screen fade), the CRT and metal shaders, the logo model, the two sounds and the `splash_whoosh` cue. `Global_Manager_SFX.play` gained an optional pitch multiplier. Differences from Pogne: no SFX-bus volume ride (a skip fades the stinger and cuts the whooshes). Tests: `Tests/test_splash.gd`. Games started earlier: pull with `-Direction ToGame`, then hook Main like the base's.
## 2026-11-17 (step 6): a helper for slow work on a thread

- **`Component_Background_Job`** (new): run slow, pure work on a thread and always show the latest result. `request(input)` as often as you like; it waits `debounce` seconds after the last request, runs one job at a time (requests that arrive meanwhile are merged), and emits `finished` only for the newest request, so a slow old answer can never overwrite a newer one. `cancel()` and `busy_changed` are there too. The work function must be pure (no nodes). Tests: `Tests/test_background_job.gd`. Games started earlier: pull with `-Direction ToGame`.
## 2026-11-17 (last): menu rumble, and cues that follow an event's value

- **Menu rumble** (new data): `Data/Rumble/menu_navigate`, `menu_confirm`, `menu_cancel` and `menu_adjust` buzz the pad very lightly on the four menu events, next to the menu sounds. All strengths are GUESS until felt. The rumble strength setting scales them, and 0 turns them off.
- **Value-driven cues** (new): `Logic_Bus_Trigger.connect_trigger_value` passes an event's first argument to a cue. A sound cue with `pitch_from_value` takes its pitch from that value (0 to 1, between `value_pitch_min` and `value_pitch_max`); a rumble effect with `strength_from_value` scales its strength the same way. Used for a sound that rises as an amount grows. Tests: `Tests/test_bus_trigger_value.gd`.
- A rumble test that used `menu_confirmed` as a stand-in trigger now uses `save_completed`, because the real menu buzz also listens to the menu events.
Games started earlier: pull with `-Direction ToGame` (the menu rumble files arrive with it; delete them if the game wants no menu buzz).
## 2026-11-17 (final): triggers as gameplay buttons

- `Logic_Input_Layout.axis_for_action` (new) and `TRIGGER_THRESHOLD`: Godot reports the triggers (ZL/ZR, LT/RT) as axes, not buttons, so an action can now be bound to a trigger. `Input_Source_Gamepad` reads such an action as pressed past the threshold. `count` is the right trigger. Games started earlier: pull with `-Direction ToGame`.
## 2026-11-17 (latest): rumble priority, and the puzzle buttons settled

From Picrops' puzzle screen (step 5d).
- **Rumble priority** (new): `Data_Rumble_Effect.priority` (0 by default). A lower-priority effect never cuts off a higher-priority one that is still buzzing; the same or a higher priority replaces it. This fixes two cues that fire together (for example "solved" and "item acquired") replacing each other on the pad. Games started earlier: pull with `-Direction ToGame`; nothing changes until a cue is given a priority.
- **Gameplay buttons**: `mark` (top button), `count` (a trigger), `undo` and `redo` (the shoulders) replace the earlier `alt_interact` and `alt_count` (they were never used by a game yet). Keyboard: C, X or Shift, Z, Y. A game that does not use them ignores them.
## 2026-11-17 (later): stopwatch, and a faster grid cursor

From Picrops' puzzle screen (step 5d).
- **`Logic_Stopwatch`** (new): a stopwatch that counts up, fed with frame time, with a `00:02:00` formatter. Tests: `Tests/test_stopwatch.gd`.
- `Logic_Grid_Cursor` repeats faster than a menu by default (0.07 s a step; menus keep 0.12 s). It is still `repeat.repeat_rate` on the cursor if a game wants another speed.
Games started earlier: pull with `-Direction ToGame`.

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
