# Base changelog

Newest first. One entry per upgrade of the base: what changed, which game it came from, and whether games started earlier need to pull it (`tools/sync_with_base.ps1 -Direction ToGame`).

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
