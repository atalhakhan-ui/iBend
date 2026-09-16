# Clamshell

A macOS menu-bar app that plays a transition across the whole screen when you close and
open your MacBook lid. Twenty transitions, twelve palettes, separate choices for opening
and closing.

![menu bar app](https://img.shields.io/badge/macOS-14%2B-black) ![swift](https://img.shields.io/badge/Swift-6-orange)

## Build and run

```bash
./build.sh && open build/Clamshell.app
```

It runs as a menu-bar item (no Dock icon). The gallery opens on first launch; after that
it lives behind the laptop icon in the menu bar.

Requires Xcode 26 / Swift 6 and macOS 14+. The build script assembles `build/Clamshell.app`
from the SwiftPM executable and ad-hoc signs it, which is what makes *Launch at Login* stick.

## What triggers a transition

| Trigger | Default | Notes |
|---|---|---|
| Lid open / close | on | Read from `AppleClamshellState` in the IOKit power registry |
| Sleep / wake | on | `NSWorkspace` sleep and wake notifications |
| Screen lock / unlock | off | Distributed notifications |

Several of these fire for a single physical gesture — closing the lid emits a clamshell
change *and* a sleep notification — so every trigger funnels through one debounced path.

**A caveat worth knowing:** when you close the lid on a laptop with no external display,
macOS cuts the backlight almost immediately, so you will barely see the closing transition.
It is fully visible when an external display stays awake (clamshell mode), on screen lock,
and from *Preview* in the menu. The **opening** transition is the one you actually watch
every time, because the overlay is already covering the screen when the display comes back.

## The transitions

| | | |
|---|---|---|
| **Duo** — two colour ribbons sweep past each other | **Clamshell** — the screen hinges open along its middle | **Iris** — a circular aperture opens from the centre |
| **Shutter** — camera blades rotate away | **Aurora** — soft light fields drift apart | **Liquid** — an organic blob draws itself inward |
| **Venetian** — horizontal slats tilt and collapse | **Mosaic** — a grid of tiles scatters | **Hex** — honeycomb cells retreat in a radial wave |
| **Curtain** — two panels part, trailing a seam of light | **Ripple** — rings run outward as the colour retreats | **Warp** — light streaks accelerate out of the centre |
| **Fold** — vertical panels fold like an accordion | **Glimmer** — a diagonal band of light wipes the screen | **Dissolve** — a fine grain of tiles blinks out |
| **Halo** — a single soft halo breathes and clears | **Ink** — blots of colour merge and lift away | **Slide** — a sheet leaves upward with parallax |
| **Bars** — vertical bars spring away, centre outward | **Spiral** — a radar sweep unwinds around the centre | **Random** — a different one every time |

Palettes: Duo, Aurora, Sunset, Midnight, Mono, Ember, Mint, Bloom, Deep Sea, Paper, Ink, Vapor.

## How a transition is written

Each transition describes only two end states — `covered` and `open` — plus a normalised
slice of the timeline. The `Timeline` resolves that into Core Animation objects for whichever
direction is playing, reversing both the values *and* the stagger order when opening. So one
description gives you both the close and the open, and they are mirror images by construction.

```swift
t.add(panel, "transform",
      covered: nv(CATransform3DIdentity),
      open: nv(Geo.transform(translate: CGPoint(x: 0, y: -half), rotateX: 0.42, perspective: 1400)),
      begin: 0.1, span: 0.9, curve: .anticipate)
```

`begin` and `span` are expressed on the *closing* timeline. Animations run on the render
server, so the overlay stays smooth at full screen resolution.

To add one: conform to `Transition`, then list it in `TransitionLibrary.all`.

## Inspecting transitions without a display

Screenshotting a full-screen overlay is awkward, so the app can render itself to PNG:

```bash
./build/Clamshell.app/Contents/MacOS/Clamshell --contact-sheet ~/Desktop/sheets duo
./build/Clamshell.app/Contents/MacOS/Clamshell --frame iris 0.5 ~/Desktop/iris.png
```

Contact sheets show every transition sampled at 0%, 25%, 50%, 75% and 100% coverage over a
checkerboard, so gaps in coverage and mistimed fades are obvious. This path evaluates the
timeline analytically and rasterises with `CALayer.render(in:)`, which honours masks but
ignores running animations and flattens non-affine transforms — a 3D rotation reads as a
squash in the sheet and looks correct on screen.

## Safety

The overlay sits above everything and ignores mouse events, so it is deliberately hard to
get stuck: coverage is released automatically if the machine never actually sleeps, a
watchdog hides the overlay after 20 seconds awake no matter what, and **Hide Overlay Now**
in the menu is an unconditional escape hatch.

## Layout

```
Sources/Clamshell/
  Transitions/     the animation engine, palettes and the 20 transitions
  System/          lid monitoring, overlay windows, playback, offscreen renderer
  UI/              menu bar, gallery, live previews
```
