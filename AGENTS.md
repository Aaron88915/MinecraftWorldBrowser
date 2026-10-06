# Project UI Regression Rules

- Text drawn on custom glass or translucent controls must be alpha-composited. Use `Graphics.DrawString` through `GlassTextRenderer`; do not use a drawing API that can paint an implicit opaque text background.
- Any change to glass-control text rendering must pass pixel-level regression coverage in both light and dark themes.
- Every rounded child control, including buttons, filters, search surfaces, cards, list shells, and detail surfaces, must use the parent's real painted background. Outer corner pixels must match the parent pixel-for-pixel; do not reconstruct a translucent parent background inside a rectangular child canvas.
- Native child controls that cannot be transparent, such as `TextBox`, must sit on a uniform material matching their exact `BackColor`; do not place them over a sheen or gradient that reveals their rectangular bounds.
- The current UI uses Telegram-inspired flat surfaces. Preserve a clear hierarchy through surface color, spacing, subtle dividers, and contrasting input boundaries. Legacy glass surfaces, if reintroduced, must retain visible highlight contrast without exposing the native child's rectangular bounds.
- Inspect buttons, filters, search surfaces, and cards at high zoom before declaring square-canvas or compositing artifacts fixed.
- Before packaging a release, render and inspect both light and dark previews in addition to running the automated self-test and EXE smoke tests.
- Flat surfaces use uniform fills and restrained single-pixel boundaries; avoid paired neumorphic shadows.
- Pointer press feedback must change the surface color without moving text, icons, or layout. The transition must remain interruptible and complete in roughly 100-160 ms. Keyboard feedback is immediate.
- Every interaction change must test normal, pressed, and released states in both themes. Released pixels must restore the normal state, and pressed rounded corners must still match the real parent background pixel-for-pixel.
- Scan progress tracks must inherit the actual footer/parent surface in both themes; do not use the global divider color as a standalone rectangular track background.
- World-list wheel retargeting must use the currently presented animation position, matching the directory list, so rapid direction changes reverse from the visible frame instead of jumping from the underlying row index.
- Directory scrollbar thumbs must paint on the same canvas as list rows so selection and hover colors continue beneath them. Preview fixtures must overflow the directory viewport in both themes; test scrollbar background pixels, press/release, dragging, and scrolled selection.
- Secondary buttons and closed filters must remain distinguishable from the canvas in their normal state, with a visible themed boundary. Test the actual toolbar/filter controls, not only isolated button fixtures.
- World rows and headers use horizontal dividers only. Paint cell backgrounds without antialiased rectangular edges, preserve graphics state, and avoid native cell-frame fallbacks. Verify selected/unselected column edges after horizontal scrolling in both themes and inspect a live screen capture as well as DrawToBitmap previews.
