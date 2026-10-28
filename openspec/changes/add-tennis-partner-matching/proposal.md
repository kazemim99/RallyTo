## Why

Racket-sport players in Iran (tennis, padel, badminton) find partners through club word of mouth, coaches and
Telegram/WhatsApp groups. Those channels cannot filter by sport, level, gender, club or time, so players either
play with whoever is around or waste scarce, expensive court time. Products that solve this abroad (Kort, Spin,
Playtomic open matches, Global Tennis Network, CourtBuds, Jugá Tenis; see `research.md`) are not built for
Iran: no Persian/RTL or Jalali calendar, no Iranian phone sign-in, no local app stores, and a reliance on
Google/Apple services and foreign payments. Rallyto fills that gap, starting greenfield on the same stack as
AsanRezerve so the team can reuse its architecture, tooling and operational knowledge.

## What Changes

A new product: backend API, Flutter player app and Vue admin panel. The MVP delivers:

- **Phone sign-in.** OTP over SMS, no passwords. Player and admin are roles on one account model. Players can
  delete their account.
- **Multiple sports.** Tennis, padel, badminton and squash are seeded, and admins manage the sport catalog.
  Each sport defines its play formats: tennis and badminton allow singles or doubles, padel is doubles (2v2),
  and squash is singles.
- **Player profile.**
  - Basic fields: display name, optional photo, gender, birth year (shown only as an age range) and city.
  - Gender is required at sign-up and only an admin can change it, so nobody can game the gender filter.
  - For each sport the player sets:
    - a **self-declared level** on five described tiers: Beginner, Lower-intermediate, Intermediate,
      Advanced, Professional;
    - **playing experience** as a duration band (under 6 months, 6–12 months, 1–3 years, 3–5 years,
      over 5 years);
    - preferred formats and goals (rally/practice, friendly match, competitive set, fitness).
  - Home clubs.
  - **No personal location or address is collected, and the phone number is never shown.**
- **Venue catalog.** All provinces and cities of Iran, and the clubs in each city with the sports and courts
  they offer (count, indoor/outdoor, surface, lighting).
  - Only the Rallyto team enters clubs. Clubs across the country are imported from Google Maps (Places)
    and approved by an admin, and missing clubs are added by hand.
  - Clubs have no accounts and no management features: the product is for finding practice partners, not for
    running clubs.
- **Availability.** A player publishes when they can play, per sport, at one or more clubs:
  - recurring weekly windows (for example Saturday and Monday 18:00–24:00 at Esteghlal Tennis Club,
    Tehran) or one-off dates;
  - each window can be paused or expire.
- **Play posts (open invitations).** A concrete game at a date, time and club, with:
  - sport, format and number of open spots;
  - desired level range and partner gender (any, male or female);
  - whether a court is already booked, plus an optional note on how the court cost is shared.
  - Other players request to join, and the host accepts or declines each request.
- **Partner search.**
  - Filters: sport, city, clubs, date or weekday, time window, level range, gender and format.
  - Results: open play posts plus players whose availability overlaps the requested window, ranked by
    closeness of fit.
  - Saved searches notify the player when a new post or player matches.
- **Invitations and matches.**
  - A player invites someone found through search to a concrete slot. The invitee can accept or decline,
    and either side can cancel.
  - An accepted invitation or join request becomes a **match** with its participants.
  - After the slot, participants confirm the match happened or report a no-show. Late cancellations are
    recorded.
- **Chat.**
  - Real-time one-to-one chat, plus a group chat per match for doubles and padel.
  - First contact from someone the player has never played with arrives as a **message request**, which
    the player accepts or ignores.
  - Text only, with read receipts.
- **Ratings and reliability.**
  - Only participants of a match confirmed as played can rate each other, within 7 days.
  - A rating is 1–5 stars, plus quick tags (on time, friendly, fair line calls, good rally), plus
    feedback on whether the declared level was lower than, about or higher than their real level.
  - Ratings are **double-blind**: each side sees the other's rating only after both have rated or the
    window has closed.
  - A player's averages appear only after 3 ratings. A reliability indicator is computed from no-shows
    and late cancellations.
- **Trust and safety.**
  - Blocking removes two players from each other's search results, posts and chat.
  - Players can report a user, message or post, and reports go to a review queue.
  - An admin reviews reports and can warn, suspend or ban.
  - A player can choose to be visible only to players of their own gender.
- **Notifications.** An in-app notification center plus push, for invitations, join requests, messages,
  match reminders, rating prompts and saved-search hits.
- **Admin panel.** Sport and venue management (import review, bulk approval, manual entry), the report queue,
  user management and basic usage metrics.

Out of scope for this change, but kept possible:
- club accounts or club management of any kind
- court booking and payment with clubs
- a coach marketplace
- leagues, ladders and tournaments
- automatic levels computed from match results
- score tracking
- paid tiers
- a web player app

## Capabilities

### New Capabilities

- `identity-access`: phone OTP sign-up and sign-in, JWT sessions and refresh, roles (player, admin), account
  suspension, account deletion.
- `sport-catalog`: the sports and their play formats (singles/doubles, players per side) and the five-tier
  level scale with player-facing descriptions per sport. Admin-managed.
- `player-profile`: identity fields, gender and age-range privacy, city, per-sport level, experience, formats
  and goals, home clubs, gender-visibility setting.
- `venue-catalog`: Iran's provinces and cities, clubs and the sports and courts each offers, import of
  candidate clubs from Google Places, admin review and bulk approval, manual entry by admins.
- `availability`: recurring weekly and one-off availability windows per sport and club, pausing and expiry,
  overlap rules.
- `play-posts`: open invitations with open spots, level/gender requirements, court-booked flag, join requests
  and host approval.
- `partner-search`: filtered search over play posts and overlapping availability, ranking, saved searches
  and their alerts.
- `match-lifecycle`: direct invitations, the match record and its states (proposed, confirmed, cancelled,
  played, no-show), late-cancellation and attendance confirmation.
- `chat`: one-to-one and match-group conversations, message requests, real-time delivery, read receipts,
  history.
- `player-ratings`: post-match ratings, level-accuracy feedback, double-blind reveal, aggregate thresholds,
  reliability indicator.
- `trust-safety`: blocking, reporting, the admin report queue and enforcement actions, enforcement of blocks
  and bans in every other capability.
- `notifications`: in-app notification center, push delivery with fallback, per-type preferences, reminders.

### Modified Capabilities

None. This is a greenfield project; `openspec/specs/` is empty.

## Impact

- **New repository layout** (monorepo, like AsanRezerve): `src/` (.NET host plus one Domain / Application /
  Infrastructure / Api set per bounded context), `tests/`, `rallyto-app/` (Flutter), `rallyto-admin/`
  (Vue 3), `docker-compose.yml` and `docker-compose.prod.yml`, and `.github/workflows/`.
- **Infrastructure**: PostgreSQL, Redis and Seq. CAP runs on the PostgreSQL outbox with the in-memory
  transport, and there is no message broker.
- **External services**:
  - SMS gateway for OTP (MeliPayamak, as in AsanRezerve);
  - push notifications (Firebase Cloud Messaging, as in AsanRezerve);
  - Google Maps Places API, used only by an offline import tool that finds candidate clubs. The tool runs
    outside Iran, because Google Maps Platform does not serve Iranian accounts or IP addresses.
  - profile photos stored on a mounted volume behind a storage interface, as AsanRezerve does.
  - The Neshan map is used only to show where a club is, never to locate a player.
- **Stack deviation from AsanRezerve**: .NET 10 LTS instead of .NET 9, because .NET 9 reaches end of support
  on 2026-11-10. Library choices otherwise follow AsanRezerve.
- **Personal data**: phone numbers, gender, birth year, chat messages and reports. These need masking in
  logs, a retention policy for chat and reports, account deletion, and hosting inside Iran.
- **Distribution**: Android first (Cafe Bazaar, Myket, direct APK). iOS builds are produced but not
  published in this change.

## Product Decisions

Confirmed by the product owner on 2026-10-23. Each one took the recommended option.

1. **Minimum age**: 18+ only in the MVP. Supporting minors would need guardian consent and stricter chat
   rules.
2. **First contact in chat**: the message-request gate described above, not open chat.
3. **Same-gender visibility**: offered as an optional per-player setting.
4. **Public written reviews**: none in the MVP. Ratings are stars and tags, with an optional private note to the
   admin.
5. **Monetization**: the MVP is free. Club partnerships, featured posts or a premium tier are revisited
   after launch.
6. **Launch scope** (revised 2026-10-23): nationwide. The venue catalog covers every province of Iran. The
   Rallyto team enters every club itself (Google Places import plus manual entry); players and clubs cannot
   add clubs. The product owner has reviewed the Google terms question and sees no legal obstacle for this use
   in Iran.
7. **Push notifications**: Firebase Cloud Messaging, as AsanRezerve uses in production without problems. No
   second push provider. The in-app notification center remains the record of every notification.
8. **Report handling**: the admin reviews reports. There is no separate moderator role.
9. **Infrastructure**: the server and domain are not provisioned yet. Nothing before deployment depends on
   them.
