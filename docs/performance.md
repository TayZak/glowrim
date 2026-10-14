# GlowRim 1.2 rendering measurements

Measured locally on an Apple M1 Pro, AC power, Low Power Mode off. The overlay runs in a Release-optimized harness with the control window absent; CPU is process user + system time divided by elapsed wall time, expressed as a percentage of one core. Each case warms up for one second and runs for eight seconds. Background desktop activity can affect results.

| Overlay | 1.1 CPU | 1.2 CPU | 1.2 draws in 8 s |
| --- | ---: | ---: | ---: |
| Off | 0.004% | 0.003% | 0 |
| Stable HDR, unchanged headroom | 0.186% | 0.015% | 0 |
| Breathing HDR | 3.296% | 1.169% | 120 |

The breathing test used 30 updates/s in 1.1 and 15 updates/s in 1.2. The curve is continuous in elapsed time, with a smooth 3.1-second inhale, a 4.6-second exhale, and a short rest at normal speed. The halo's width and diffusion follow the same envelope. Slow spatial variation bends the inner contour; the outer display boundary stays fixed.

An offscreen FP16 GPU comparison used the saved 1.1 shader, actual screen dimensions (1496 × 967 points), the previous Retina target (2992 × 1934 pixels), and the new 1000 × 647 target. Median command GPU duration over 100 measured frames, after 20 warm-up frames:

| GPU rendering | 1.1 | 1.2 |
| --- | ---: | ---: |
| GPU time / image | 0.2050 ms | 0.0513 ms |
| Fragment pixels / image (sample frame) | 5,786,528 | 271,746 |
| One FP16 color surface | 44 MiB | 4 MiB |

This is roughly 65% less process CPU in the breathing harness, 75% less GPU rendering time per image, and 95% fewer shaded pixels per image. These are rendering measurements, not total system energy or battery-life estimates. Display illumination and WindowServer composition are outside this benchmark. Metal may retain a small allocation cache after the view closes; the app releases its drawable surface and submits no further frames when off.

## Resource policy

- AC: up to 15 updates/s, at most 1000 pixels on the longest side.
- Battery: up to 12 updates/s, at most 850 pixels.
- Low Power Mode or serious thermal pressure: up to 8 updates/s, at most 640 pixels.
- Stable SDR: no render timer and no redraw while unchanged.
- Stable HDR: a headroom query every two seconds; no redraw unless the gain changes or controls/display configuration change.
- Light off: no render timer, no overlay window. Battery updates use IOKit notifications. Automatic breathing uses one five-minute deadline rather than a permanent polling timer.
- The preview is a static native shape, with no animation timer or additional Metal surface.

Run `./scripts/profile.sh Tests/Fixtures/Rim-1.1.metal` to reproduce the current CPU cases and the GPU comparison. It briefly shows each lighting mode on the primary display. The saved fixture is benchmark-only and is not part of the app target.
