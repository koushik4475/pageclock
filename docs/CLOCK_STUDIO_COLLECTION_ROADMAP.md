# PageClock Clock Studio — Collection Roadmap

## Current collections

The Clock Studio gallery keeps the original ten saved face IDs and adds the six selected Classic faces. Collections are a presentation layer only; the selected face remains stored as the existing `clockStyleId` setting, so no data migration is needed.

| Collection | Included templates | Purpose |
|---|---|---|
| Classic | Braun Minimal, Railway Classic, Roman Heritage, Regulator, Classroom Clear, Night Lume, original Analog | Familiar dials, at-a-glance reading, traditional clockmaking |
| Digital | macOS Flip, Nixie Tube, Dot Matrix, Retro LCD, Terminal, Binary | Large digital time, retro displays and technical readouts |
| Ambient | Neon Glow, Aurora | Atmospheric full-screen desk and bedside displays |
| Editorial | Editorial | Typographic, low-clutter display |

## Design principles for future collections

1. Readability comes before ornament: clear contrast, distinct hour/minute hands, a useful minute track and numerals sized for the actual display.
2. Every face must support the same information contract: live wall time, focus countdown, stopwatch/overtime, optional date and optional seconds.
3. Avoid motion that competes with reading. Any animation must be subtle, pause-safe and disabled or reduced when the device requests reduced motion.
4. Previews must use the real renderer, not static images, so the selected face behaves exactly like the fullscreen clock.
5. Existing face IDs and the default `mac_flip` must remain stable for saved preferences and old backups.

## Proposed next collections (design proposals, not yet implemented)

### 1. Modern
- Bauhaus Geometry — simple geometric indices and primary-colour accents.
- Mono Index — monochrome baton dial with no numerals.
- Soft Glass — translucent, but with an opaque high-contrast time layer.
- Gridline — precise grid and typographic time, no decorative animation.

### 2. Nature
- Ocean Tide — deep blue dial, restrained wave-like minute track.
- Forest Dusk — muted green and warm ivory numerals.
- Lunar Phase — dark sky palette with a simple moon-phase indicator.
- Desert Sunrise — warm sand dial with low-saturation horizon tones.

### 3. Productivity
- Focus Ring — central countdown with a progress arc.
- Pomodoro Blocks — focus/break phase and remaining time clearly separated.
- Session Stopwatch — elapsed time as the primary value.
- Overtime Count-up — explicit plus sign and distinct overtime state.
  
These should be mode-aware layouts rather than decorative clock faces; they must never obscure the timer's current state.

### 4. Travel & World Time
- Dual Time — local and selected secondary timezone with clear labels.
- World Dial — one prominent local dial plus a secondary city label.
- 24-Hour Rail — continuous 24-hour track for schedule awareness.

A timezone face must label each city/timezone and use the device's actual timezone data; it must not imply an unselected city or silently change the device clock.

### 5. Instrument
- Aviation Chronometer — strong indices, compact secondary time/date.
- Field Watch — robust minute track and high-contrast hands.
- Studio Meter — stopwatch-oriented elapsed-time presentation.

## Reference research

- [Cooper Hewitt — Ahead of the Times](https://www.cooperhewitt.org/2018/02/24/ahead-of-the-times/): Braun dial restraint, economical colour and readable typography.
- [MONDAINE — Swiss railway station clock design](https://uk.mondaine.com/blogs/news/the-story-behind-the-iconic-swiss-railways-station-clock): contrast, bold markers and the red seconds hand.
- [Network Rail — Timepiece: Designing Modern Time](https://www.networkrail.co.uk/wp-content/uploads/2025/10/Timepiece-Designing-Modern-Time.pdf): dial hierarchy, the length and weight of hands, numeral legibility and minute subdivisions.
- [RIBA — Timepiece design notes](https://ribacompetitions.com/nr-timepiece/downloads/Timepiece_Designing_Modern_Time.pdf): proportion and the visual importance of minute indexes.

Only the six Classic faces are included in the current feature branch. The next collections above remain proposals until selected and reviewed.
