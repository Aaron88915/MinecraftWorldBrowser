# Project UI Regression Rules

- Text drawn on custom glass or translucent controls must be alpha-composited. Use `Graphics.DrawString` through `GlassTextRenderer`; do not use a drawing API that can paint an implicit opaque text background.
- Any change to glass-control text rendering must pass pixel-level regression coverage in both light and dark themes.
- Every rounded child control, including buttons, filters, search surfaces, cards, list shells, and detail surfaces, must use the parent's real painted background. Outer corner pixels must match the parent pixel-for-pixel; do not reconstruct a translucent parent background inside a rectangular child canvas.
- Native child controls that cannot be transparent, such as `TextBox`, must sit on a uniform material matching their exact `BackColor`; do not place them over a sheen or gradient that reveals their rectangular bounds.
- Fixing a compositing seam must not flatten the intended glass hierarchy. Keep specular edge light, restrained depth, and shadow outside the native child's bounds, and test that the material still has visible highlight contrast.
- Inspect buttons, filters, search surfaces, and cards at high zoom before declaring square-canvas or compositing artifacts fixed.
- Before packaging a release, render and inspect both light and dark previews in addition to running the automated self-test and EXE smoke tests.
- Neumorphic surfaces use one consistent light direction: a light upper-left outer shadow and a dark lower-right outer shadow in the raised state.
- Pointer press feedback must replace the paired outer shadows with paired inset shadows without moving text, icons, or layout. The transition must remain interruptible and complete in roughly 100-160 ms.
- Every neumorphic interaction change must test raised, pressed, and released states in both themes. Pressed rounded corners must still match the real parent background pixel-for-pixel.
