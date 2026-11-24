# Performance

Target: MacBook Air M4, Medium preset, 60 FPS, frame time at or under 16.6 ms (aim about 12 ms average).

## Measured results
| Date | Build | Machine | Preset | Avg FPS | 1% low | Worst frame | Hitches >33 ms |
|---|---|---|---|---|---|---|---|
| 2026-11-12 | 0.1.0-m1 | MacBook Air M4 15" (2940 x 1846, Metal) | High, 100% scale | 33.0 | 27.1 | 39.8 ms | 140 |
| 2026-11-12 | 0.2.0-m2 | same | High, 1720 x 1080 (59%), MetalFX | 84.7 | 60.5 | 33.4 ms | 1 |
| 2026-11-13 | 0.3.0-m3, Dead City | same | High effects at 1720 x 1080 (59%), MetalFX | 80.1 | 57.0 | 22.6 ms | 0 |
| 2026-11-13 | 0.3.0-m3, Dead City | same | **Medium**, 1720 x 1080 (59%), MetalFX | 112.2 | 57.8 | 20.7 ms | 0 |
| 2026-11-13 | 0.3.0-m3, Dead City | same | High (fixed), 2548 x 1600 (87%), MetalFX | 45.9 | 38.3 | 27.1 ms | 0 |
| 2026-11-13 | 0.4.0-m4, Dead City | same | Medium, 1720 x 1080 (59%), MetalFX | 104.0 | 47.4 | 211.6 ms | 1 |

The build workspace has no GPU, so no figure from it is recorded here.

Reading of the High result: frame time was flat at about 30 ms, which points at the GPU shading 5.4 million pixels with full-resolution SSAO, SSR and volumetric fog. Response (0.2.0-m2): each preset now caps the 3D image height (`max_render_height`: Low 900, Medium 1080, High 1600) and upscales with MetalFX. On this display Medium renders at about 1720 x 1080 (58%). Medium still needs to be measured.

Reading of the M2 High result: capping the 3D resolution took High from 33 to 85 FPS in the Proving Ground (299 draw calls, 169k triangles), with 99.8% of frames inside 16.7 ms. That is a test level. The Dead City adds rain particles, 82 point lights and up to 10 animated enemies in the benchmark fight, so it needs its own measurement before any claim about 60 FPS.

Reading of the M3 result (Dead City, 334 draw calls, 179k triangles, ten-enemy fight on the route): 12.5 ms average, p99 16.67 ms, 99.0% of frames inside 16.7 ms, no hitches. Both "High" rows above were really High effects at Medium's resolution: the owner's settings file was written by the M1 build, before presets had a resolution cap, so the cap stayed at the default 1080 instead of High's 1600. Fixed after this run (a named preset now always loads its current values). Medium and true High were measured afterwards (rows above).

Reading of the Medium and true-High results (2026-11-13):
- **Medium meets the target on average**: 8.9 ms (112 FPS), 98.9% of frames inside 16.7 ms, no hitches. Split into 5-second segments, eleven of twelve sit at 110 to 120 FPS with a p99 near 10.5 ms. One segment (about 24 to 29 s into the route, between the Main Street and metro stops) dropped to 90 FPS with 67 frames over 16.7 ms (worst 20.7 ms). That one spell is the whole reason the 1% low reads 57.8. The same segment was clean in the 00:45 run with heavier effects, so it is not a fixed cost of that view; the cause is not identified from one run.
- **True High misses 60 everywhere**: 21.8 ms flat across the whole route, so it is bound by resolution, not by any one scene. From the two High-effects runs (1.86 million pixels at 12.5 ms, 4.08 million at 21.8 ms) the cost is roughly 4.7 ms plus 4.2 ms per million pixels. By that estimate High would need a cap near 1240 pixels tall to average about 15 ms. This is an estimate, not a measurement.

Reading of the M4 Medium run (2026-11-13 11:19): the game ran as fast as before, but 10.1 seconds of the run were paced at exactly the display's 60 Hz (0.1 to 0.5 s, 6.8 to 11.2 s, 15.2 to 20.4 s; average 16.67 ms in each). Outside those stretches it averaged 8.85 ms (113 FPS, against 112 in the M3 run) with 15 frames of 5,635 over 16.7 ms. Nothing in the game switches the frame limit or VSync back on during a benchmark and nothing would then switch it off again, so the pacing came from outside the game; the likely cause is macOS compositing the full-screen game for a while (a notification, another window or an overlay on top), but that is not proven. The 211 ms frame at 0.9 s is a single start-of-run hitch. This run's 1% low and "frames within 16.7 ms" should not be compared with the others. From the next build the report states how many seconds were held at the display rate.

## How to run the benchmark on the Mac
In game: Esc, then "Run performance benchmark (60 s)".

From Terminal (folder containing the app):
```
"./Ghostline.app/Contents/MacOS/Ghostline" -- --benchmark --benchmark-seconds=60 --benchmark-preset=medium --benchmark-quit
```
Results are written next to the app in `Ghostline-benchmarks/` (a `.txt` summary and a `.csv` of frame times).

## Budgets
See section 15 of the build brief. Dead City static world: 681 boxes in 12 MultiMesh draw calls (about 8k triangles) plus characters and particles; one shadowed directional light, four shadowed lamps and 78 small unshadowed point lights that fade out by distance (30 to 70 m). The light count is the main performance risk and the first thing to cut if Medium misses 60; rain is 900 / 1800 / 3000 GPU particles on Low / Medium / High.

## Wanted from the owner (M5 and M6)
Since M5 all three areas have had a set dressing pass (thousands more boxes in the shared MultiMeshes, particle effects, a few dozen extra lights) and the music runs four streams at once. A fresh Medium benchmark in each area is the most useful thing now.

Nothing has been measured in the two new areas. Please run Medium in each and send the `.txt` files:
```
"./Ghostline.app/Contents/MacOS/Ghostline" -- --level=forest --benchmark --benchmark-seconds=60 --benchmark-preset=medium --benchmark-quit
"./Ghostline.app/Contents/MacOS/Ghostline" -- --level=facility --benchmark --benchmark-seconds=60 --benchmark-preset=medium --benchmark-quit
```
The Forest scatters up to 1,500 trees before clearings are cut out (two MultiMeshes, scaled by the foliage setting), grass patches and one shadowed sun; the Facility is small rooms with many unshadowed point lights, volumetric fog and the Choir fight at the end of the route. The Forest is the likelier of the two to miss 60.
