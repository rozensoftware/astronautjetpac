# Astronaut Jet Pac: A Retro Amiga Experience
(Jetpack-inspired gameplay)

Version 1.0.4

The core gameplay experience has now reached its intended status. Development efforts have shifted from adding major features to focusing on polish and stability. Future updates will therefore be less frequent, typically addressing bug fixes, optimizing performance, and refining the retro presentation. ✨

Music MODs by GrOgOn/CdS and cartoon

## Text Rendering

Requires a HAS checkout with `lib/textbob.s` and `PrintToBob` support. Build
the 68000 game with `make jetpac`.

Title, ladder, name-entry labels, bonus and GAME OVER text are baked into
masked BOBs and blitted instead of rendered glyph-by-glyph every frame. Menu
caches are released before gameplay. The HUD is rebaked only when its values
change, retaining per-buffer dirty flags and background-strip restoration.
Text falls back to the CPU renderer if a BOB allocation fails.

Runtime validation on an Amiga or emulator:

- Check title/ladder cycling and updated names/scores after a new high score.
- Change score, lives, level and fuel; check both buffers for stale HUD pixels.
- Collect a bonus and check that its text disappears cleanly when it expires.
- Repeat GAME OVER, restart and exit; check for missing text or memory loss.

## Copyright

Copyright (c) 2026 Rozsoft

## License

See [LICENSE](LICENSE) for the project terms.
