# Figma Make export: Rallyto Mobile App Design

The approved mobile design, exported from Figma Make (2026-10-24) as a clickable React prototype. It is a **visual reference only**:
the Flutter app in `rallyto-app` implements it; nothing here is shipped.

- `index.css`: design tokens (`:root` colours, radii, shadow) and every component's styling.
- `App.tsx`: all screens and their states (home, search, player, invite, post, match as host/guest, my matches, chats,
  conversation, profile, design system, sign-in, onboarding).
- `favicon.svg`: the brand mark.

The Flutter app adjusts a few colours slightly so every text/background pair meets WCAG AA 4.5:1 (see
`rallyto-app/DESIGN_SYSTEM.md`).

The export predates the product's rename from TennisYar to Rallyto (رالیتو, 2026-10-28); its files are kept as
delivered, so they still show the old name.
