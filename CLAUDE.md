# [GAME NAME]

Godot 4.7 game, started from `game-base` (see `tools/base_version.txt` for the base version it came from). Read `docs/DESIGN.md` (what the game is), `docs/ARCHITECTURE.md` (how it is built) and `docs/SYSTEMS_MAP.md` (how the systems connect) before doing anything.

Fill in this file for the game: who it is for, the current step, and any references.

## How to work with the owner

These are the working rules from the project this base came from. Keep or change them per owner.

- The owner is a game/UI/UX designer, not a programmer. Reply in the language the owner writes in.
- **Propose first, implement after the owner confirms.** Suggest ideas freely, but never build something not approved. Offering choices works well.
- **Explain how things connect.** Say which system owns what and which events connect them.
- **Architecture before mechanics.** Build the supporting systems before the main mechanic, so they are not refactored again and again. Follow the build order in ARCHITECTURE.md.
- Modular and data-driven over hard-coding. Never write the same system twice; reuse or extend components.
- Make targeted edits, not full-file rewrites. Re-read a file before editing it.
- The design doc holds only what the owner confirmed. Do not add guesses to it.

## Conventions (summary; full rules in ARCHITECTURE.md)

- Names go from type to specific so files sort together: `Global_Manager_`, `Manager_`, `Data_`, `State_`, `Rule_`, `Logic_`, `Component_`, `UI_`, `UI_Animator_`, `Runtime_`, `Interactable_`, `Generate_`, `Tool_`, `Debug_`, `Shell_` (title/splash/settings screens), `FX_` (camera and screen effects), `Input_Source_`.
- Files snake_case, classes and nodes Pascal_Snake; a scene and its main script share a name.
- Acronyms stay capitalized in names: `Interactable_NPC`, `Data_NPC`, `SFX`, `UI`. Never `Npc`.
- Signals are past-tense events; private members start with `_`; constants UPPER_CASE; ids are StringName.
- Comments explain why, with `# === Name ===` section headers. Mark untested tuning values with `GUESS:` comments.
- No absolute node paths. Managers hold logic; UI displays state and sends intents. Systems talk through `Global_Manager_Events`. Data is read-only at runtime; one writer per State.
- Controller-first. Every screen is navigable by gamepad from day one.

## Current step

(Fill in. A new game starts after the base: its data, its events, its first mechanic. Each step ends with one boundary test (GUT), plus a hardware check where it applies.)

## Reuse and the base

`docs/SYSTEMS_MAP.md` explains every system. `tools/base_files.txt` lists the files that should match the base; `tools/diff_against_base.ps1` shows which differ. The base is the upstream for reusable code: fix a base file in the base first, then bring it into this game. The event bus has a BASE block and a GAME block; add the game's events to the GAME block.

## Tooling notes

- Run all tests headless: `Godot --headless --path . -s addons/gut/gut_cmdln.gd -gexit` (the Godot executable on the owner's machine is `C:\Users\jrbechard\Desktop\Godot\Godot_v4.7-stable_win64.exe`).
- Godot's editor rewrites `.gitignore` and `.gitattributes` when it opens the project; check `git status` before committing. If the owner's editor was open before new autoloads were added, use Project > Reload Current Project, or it reports them as undeclared.
- Open test windows with `--screen N` to choose the monitor; `--position` always lands on the first one.
- Esc and Space are routed menu keys that the input router consumes; debug scenes read `_input` and quit with F10.
- A scene-less test of anything that uses sound or a pad should replace the hardware call (`Global_Manager_Rumble.backend`, `Global_Manager_SFX.playback_backend`) with a recorder.
