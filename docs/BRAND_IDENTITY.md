# PageClock Brand Identity

## Approved identity

- Mark: heritage clock dial above an open book
- Wordmark: Page in charcoal, Clock in focus orange
- Tagline: READ · FOCUS · TRACK
- Typeface direction: Inter / system sans-serif

## Palette

| Token | Hex | Use |
|---|---|---|
| PageClock Cream | `#FFF4E6` | Primary light surfaces and splash background |
| PageClock Ink | `#111827` | Logo linework and primary text |
| Focus Orange | `#F97316` | Seconds hand, active state and brand accent |
| Warm Beige | `#E6D5C0` | Borders, muted surfaces and progress tracks |
| Muted Slate | `#586174` | Secondary text |

## Application

- Android launcher uses a foreground vector with separate adaptive-icon background and Android 13 monochrome layer.
- Android 12+ splash uses the PageClock cream/clock-and-book vector.
- PWA uses the branded 192px, 512px, maskable and Apple touch icons; its service-worker cache name is versioned so existing installed PWAs fetch the new icon assets.
- Settings exposes `PageClock Classic` as the featured first option in the theme gallery.
- The other eleven themes and the existing default theme remain available and unchanged.
- The logo is not baked into app-store feature graphics in this change. Google Play / App Store listing and Mac Store launch planning is deliberately deferred.

## Asset rules

Use the original square icon artwork without rounded-corner masking for platform icon masters. Android/iOS launchers apply their platform masks. Preserve clear space around the symbol and avoid embedding the wordmark in small launcher icons.
