Every group is a vertical slice that ends with the whole test suite green.
- **Test-first rule:** the first task of each slice turns that slice's spec scenarios into failing tests.
  Production code follows.
- **Spec references** in brackets point to `specs/<capability>/spec.md`.
- **Design references** (D1–D16) point to `design.md`.

## 1. Foundation

- [x] 1.1 Initialise the repository:
  - `git init` and a `.gitignore` that excludes secrets and `google-services.json`;
  - `global.json` pinning the .NET 10 SDK, `Rallyto.slnx` (the .NET 10 default solution format),
    `.editorconfig`;
  - root `Directory.Build.props` (net10.0, nullable, implicit usings, `TreatWarningsAsErrors`, analyzers).
- [x] 1.2 Add root `Directory.Packages.props` with every package version in one place. Pin MediatR 12.5.0 and
  FluentAssertions 7.x. Do not reference AutoMapper (D1, D12).
- [x] 1.3 Record the AsanRezerve commit the building blocks are forked from in
  `docs/BUILDING_BLOCKS_ORIGIN.md`.
- [x] 1.4 Fork `Rallyto.Core.Domain`:
  - `Entity<TId>`, `AggregateRoot<TId>`, `ValueObject`, `DomainEvent`, `IBusinessRule`;
  - strongly typed ID pattern;
  - leave out the folders AsanRezerve excludes from compilation.
- [x] 1.5 Fork `Rallyto.Core.Application`:
  - `Result<T>`, `ErrorResult`, `ICommand`/`IQuery`, pagination types, exceptions, `ICurrentUserService`;
  - `IDateTimeProvider` implemented over `TimeProvider`;
  - pipeline behaviors Logging → Validation → Authorization → Idempotency → Performance → Caching, ported to
    MediatR 12.5.0. Do not copy the generic `TransactionBehavior` (D12).
- [x] 1.6 Fork `Rallyto.Infrastructure.Core`:
  - `EfCoreUnitOfWork<TCtx>` with `SaveAndPublishEventsAsync`, repository bases, UTC converter, audit save hook;
  - domain-event dispatcher;
  - CAP registration with the once-per-process guard (group `rallyto`, schema `cap`, in-memory transport);
  - HybridCache over Redis with the resilient L2;
  - the `IRealtimePublisher` abstraction.
- [x] 1.7 Fork the remaining shared projects:
  - security: JWT, authenticated fallback policy, `AdminOnly`, the SignalR `access_token` extractor;
  - observability: Serilog provider pipeline, sensitive-data masking, request telemetry;
  - API middleware: response envelope, exception mapping, both rate-limiting layers.
- [x] 1.8 Create the bounded-context projects:
  - Identity, Catalog, Community, Messaging and Notifications, each with Domain / Application /
    Infrastructure / Api projects under `src/Contexts/`;
  - one DbContext per context, with its own schema and snake_case naming;
  - a per-context `I<Ctx>UnitOfWork` marker (D2, D12).
- [x] 1.9 Create `Rallyto.Host`:
  - `Program.cs` composition in AsanRezerve's order, with the production configuration guard;
  - Asp.Versioning, Swagger, anonymous health probes;
  - the `/hubs/realtime` hub with `user_{id}` groups;
  - the startup migration runner (identity, catalog, community, messaging, notifications);
  - a Dockerfile on `aspnet:10.0`.
- [x] 1.10 Add the Compose files:
  - `docker-compose.yml` with postgres, redis, seq, pgadmin and api;
  - `docker-compose.prod.yml` with GHCR images and placeholder host values (no server yet);
  - `.env.example`.
- [x] 1.11 Create `tests/Rallyto.Tests.Commons`:
  - Testcontainers PostgreSQL and Redis fixtures;
  - `DatabaseReset` (truncate all except migration history and `cap`);
  - `FakeTimeProvider` wired into the host factory;
  - decision: tests sign in for real (phone OTP through the fake SMS sender added in 2.6) instead of a test
    authentication handler, so account-status enforcement is exercised too. The fake push gateway arrives
    with section 10.
- [x] 1.12 Create `tests/Rallyto.Host.IntegrationTests` with a `WebApplicationFactory` host, and a passing
  test for `/health`, `/health/ready` and `/health/live`.
- [x] 1.13 Create `tests/Rallyto.ArchitectureTests` with these rules, all passing:
  - layer dependencies inside each context;
  - no context references another context's Domain or Infrastructure;
  - no generic transaction behavior;
  - the query-cache allowlist test.
- [x] 1.14 Add `.github/workflows/ci.yml`: build, then unit, integration (Testcontainers) and architecture tests
  on every push. Add a `deploy.yml` skeleton that stays disabled until a server exists.
- [x] 1.15 Scaffold `rallyto-app` (Flutter) by porting AsanRezerve's customer-app core:
  - dio client, and an auth interceptor with one shared refresh future;
  - get_it + injectable, go_router with a testable `redirectFor`, secure storage;
  - Jalali, Tehran-time and Persian-digit helpers, `app_strings.dart`;
  - the Vazir font and an RTL `fa_IR` `MaterialApp`;
  - a `test/` tree mirroring `lib/`, with `flutter analyze` and `flutter test` added to CI.
- [x] 1.16 Scaffold `rallyto-admin`:
  - Vite + Vue 3 + TypeScript, ant-design-vue with `fa_IR`, Pinia;
  - vue-router with an auth guard, vue-i18n with the `fa` default, `useRTL`, the axios utility;
  - Vitest, added to CI.

## 2. Identity and access [identity-access]

- [x] 2.1 Write failing integration tests for every scenario in `identity-access`.
- [x] 2.2 Implement the `PhoneNumber` value object, normalising every accepted form and Persian/Arabic digits to
  E.164, with unit tests.
- [x] 2.3 Port the `PhoneVerification` aggregate with unit tests:
  - 4-digit hashed code, valid 5 minutes;
  - 5 attempts, then a 1-hour block;
  - 60 s resend cooldown and 3 sends per 10 minutes.
- [x] 2.4 Implement the `UserAccount` aggregate with unit tests:
  - roles Player and Admin;
  - status transitions Active, Suspended until, Banned, Deleted;
  - owned `RefreshToken` with rotation and family revocation on replay;
  - the `BannedPhone` peppered hash.
- [x] 2.5 Add Identity persistence: `identity` schema configurations and the first migration.
- [x] 2.6 Port the MeliPayamak `ISmsNotificationService` adapter with the OTP template. Add the fake sender and
  `OTP_SANDBOX_CODE` for development and test.
- [x] 2.7 Implement the sign-in commands:
  - send code, verify code (creating the account and applying the initial-admin list);
  - refresh, sign out;
  - JWT issuance with a 60-minute lifetime.
- [x] 2.8 Implement account deletion confirmed by a fresh code. Implement the admin commands suspend, lift,
  ban, grant admin and revoke admin, keeping at least one admin.
- [x] 2.9 Enforce account status on every request:
  - `IAccountStatusReader` cached in HybridCache, evicted on status change;
  - a global `ActiveUser` requirement;
  - the realtime connection closed on suspension, ban or deletion.
- [x] 2.10 Publish `identity.account-suspended`, `-banned`, `-reactivated` and `-deleted` integration events
  through CAP (D3).
- [x] 2.11 Expose the endpoints:
  - `auth/otp/send`, `auth/otp/verify`, `auth/refresh`, `auth/sign-out`, `account`;
  - admin user endpoints;
  - `phone-verification` and `code-verification` rate-limit policies.
- [x] 2.12 Extend the production configuration guard (sandbox code, placeholder JWT key, sandbox SMS) and test
  it.
- [x] 2.13 Build the Flutter auth feature, with bloc tests:
  - phone entry and OTP entry (pinput + smart_auth autofill);
  - resend countdown;
  - blocked, suspended and banned messages;
  - token storage and sign-out.
- [x] 2.14 Build the admin panel's OTP sign-in for the Admin role only, plus the user list with suspend, lift,
  ban and admin-role actions, with Vitest.
- [x] 2.15 Run the full test suite and fix until green.

## 3. Sport and venue catalog [sport-catalog, venue-catalog]

- [x] 3.1 Write failing integration tests for every scenario in `sport-catalog` and `venue-catalog`.
- [x] 3.2 Implement the `Sport` aggregate with unit tests:
  - formats and capacity (padel doubles only, squash singles only);
  - five level tiers with per-sport Persian descriptions;
  - default session lengths: tennis 90, padel 90, badminton 60, squash 60 minutes;
  - seed data for tennis, padel, badminton and squash.
- [x] 3.3 Implement the admin sport commands: add, edit, reorder, deactivate. The format-removal guard goes
  behind `IFutureMatchReader`, wired in 6.11.
- [x] 3.4 Seed the 31 provinces and their cities from a static file of official divisions. List cities in
  Persian collation, with venue-bearing cities first.
- [x] 3.5 Implement the `Venue` aggregate (offered sports, status, optional coordinates, `place_id`) and the
  `VenueCandidate` aggregate (pending, approved, merged, rejected; unique `place_id`), with `catalog` schema
  persistence.
- [x] 3.6 Implement the admin venue APIs:
  - idempotent candidate import keyed by `place_id`;
  - approve, merge and reject;
  - bulk approve per city;
  - manual venue entry with a similar-name check;
  - edit, and hide (publishing `catalog.venue-hidden`).
- [x] 3.7 Implement Persian text normalisation (ي/ی, ك/ک, zero-width non-joiner, spacing) and venue name
  search, with unit tests.
- [x] 3.8 Implement the read APIs:
  - sports and level scale (anonymous);
  - provinces and cities;
  - venues by city and sport, and venue details;
  - caching through the allowlist, invalidated on catalog changes.
- [x] 3.9 Build `tools/Rallyto.VenueImport`:
  - an `IVenueSource` interface with a Google Places (New) Text Search adapter;
  - one query per city × sport keyword, with paging and throttling;
  - a dry-run JSON output, and upload to the admin import endpoint;
  - a README explaining that it runs outside Iran.
- [x] 3.10 Build the admin catalog screens:
  - candidate queue filtered by province, city and keyword;
  - approve, merge, reject and bulk approve;
  - manual add with a map pin;
  - venue list, edit and hide;
  - sport management.
- [x] 3.11 Build the Flutter catalog data layer with local cache, the venue picker (city, then venues filtered
  by sport, with search), and venue details with the club's map location only.
- [x] 3.12 Run the full test suite and fix until green.

## 4. Player profile and blocking [player-profile, trust-safety › Block a player]

- [x] 4.1 Write failing integration tests for every scenario in `player-profile` and for the block/unblock
  scenarios in `trust-safety`.
- [x] 4.2 Implement the `PlayerProfile` aggregate with unit tests:
  - `SportProfile` (level, experience band, formats, goals);
  - up to 5 home venues;
  - visibility setting;
  - the 18+ gate on the Tehran date, and age ranges.
- [x] 4.3 Implement the `Block` aggregate, block/unblock commands and API. Implement the pure
  `VisibilityPolicy.CanSee(viewer, subject)` (blocks in both directions, same-gender visibility, inactive
  accounts) with unit tests (D11).
- [x] 4.4 Add Community persistence: `community` schema for profiles and blocks, and its migration.
- [x] 4.5 Return "profile required" from every player endpoint until onboarding is complete, and expose a
  `profileCompleted` flag.
- [x] 4.6 Implement the profile commands:
  - create and update (gender cannot change);
  - add, edit and remove sport profiles (last-profile rule; future-match guard wired in 6.11);
  - set home venues (Active venues only);
  - set visibility;
  - admin gender correction, with a reason and audit.
- [x] 4.7 Implement profile photos: `IFileStorage` on a mounted volume, ImageSharp resize, JPEG/PNG/WebP up to
  5 MB, unguessable keys, admin removal.
- [x] 4.8 Implement the profile view query through `VisibilityPolicy` (age range, coarse last-active), and
  last-active tracking throttled to once per 15 minutes.
- [x] 4.9 Consume Identity account events: hide profiles of suspended or banned accounts, and anonymise deleted
  ones as «کاربر حذف‌شده».
- [x] 4.10 Add architecture tests:
  - only Identity references the phone-number type;
  - Community queries that return players go through `VisibilityPolicy`.
- [x] 4.11 Build the Flutter screens:
  - onboarding: name, gender with a "cannot be changed" notice, Jalali birth date, city, sport profiles with
    tier descriptions;
  - profile view and edit, home clubs, visibility setting, photo upload;
  - block and unblock.
- [x] 4.12 Build the admin player detail page: profile, gender correction, photo removal.
- [x] 4.13 Run the full test suite and fix until green. **Milestone: players can sign up and build profiles.**

## 5. Availability and partner search [availability, partner-search]

- [x] 5.1 Write failing integration tests for every scenario in `availability`.
- [x] 5.2 Implement the `Availability` aggregate with unit tests for the time-window value object:
  - recurring (Saturday-first weekdays) or one-off (up to 60 days ahead);
  - Tehran local minutes in 30-minute steps, at least 60 minutes, ending by 24:00, no midnight crossing;
  - 1–3 venues in one city that offer the sport, and allowed formats;
  - the duplicate/overlap rule and the 10-window limit.
- [x] 5.3 Add availability persistence and indexes (D6). Implement the commands create, edit, pause, resume,
  delete and "still available", validating venues through an in-process `IVenueReader`.
- [x] 5.4 Implement `AvailabilityStalenessWorker` (day-27 reminder event, day-30 auto-pause, one-off and
  end-date expiry) with `FOR UPDATE SKIP LOCKED`, tested with `FakeTimeProvider`.
- [x] 5.5 Consume events: a removed sport profile deactivates its windows; a hidden venue is removed from
  windows (pausing empty ones); account status changes hide or remove windows.
- [x] 5.6 Write failing integration tests for every player-result, exclusion, ranking, paging, saved-search and
  rate-limit scenario in `partner-search`. Post results come in 6.9.
- [x] 5.7 Implement the pure `PartnerRankingPolicy` with configurable weights and a deterministic tie-break,
  with unit tests.
- [x] 5.8 Implement player search:
  - defaults (profile city, tier ± 1, own gender for same-gender players);
  - at least 60 minutes of overlap;
  - all exclusions;
  - 20 results per page with a continuation token;
  - 60 searches per minute.
- [x] 5.9 Implement saved searches:
  - CRUD (up to 5, alerts toggle, expiry for date searches);
  - evaluation on availability published or resumed, from the owner's point of view;
  - throttling to one alert per 6 hours with a digest count;
  - publishing `community.saved-search-matched`.
- [x] 5.10 Build the Flutter screens:
  - availability management: weekday chips, 30-minute time range, up to 3 venues, formats, one-off Jalali
    date, "still available";
  - search with filter defaults, results showing the overlap, profile drill-in;
  - saved searches.
- [x] 5.11 Run the full test suite and fix until green.

## 6. Play posts, invitations and matches [play-posts, match-lifecycle]

- [x] 6.1 Write failing integration tests for every scenario in `play-posts`.
- [x] 6.2 Write failing integration tests for every scenario in `match-lifecycle`, except attendance (covered in
  section 8).
- [x] 6.3 Implement the `Match` aggregate with unit tests for transitions, capacity and concurrency (D4):
  - public or private; capacity from the format; players brought;
  - participant and match state machines;
  - level range, partner gender (forced for same-gender hosts), court-booked flag, cost note, description,
    share token;
  - an `xmin` concurrency token.
- [x] 6.4 Add match persistence and indexes, plus the overlap query that prevents double-booking.
- [x] 6.5 Implement the post commands:
  - create and edit (time and venue changes only without accepted players);
  - cancel;
  - join request, withdraw, accept and decline (auto-decline when full, concurrent last spot);
  - limits of 5 open posts and 10 pending requests.
- [x] 6.6 Implement the invitation and participation commands:
  - invite (private match or into an own post) and respond;
  - confirm early;
  - leave, and remove (with the 12-hour late-cancellation rule and its block exemption).
- [x] 6.7 Implement `MatchLifecycleWorker`, part 1: at start time, confirm automatically with at least 2
  players or expire, and decline pending requests.
- [x] 6.8 Consume events: account suspended, banned or deleted removes the player from future matches and
  cancels the matches they host; a hidden venue raises participant notices. Publish all match integration
  events listed in the notifications catalog.
- [x] 6.9 Complete search: post results, the busy-player exclusion, and saved-search alerts on new posts.
- [x] 6.10 Implement share links:
  - `PublicBaseUrl` configuration and token regeneration;
  - an anonymous summary endpoint without photo, age or contacts;
  - a visibility-aware signed-in view;
  - a minimal host-served fallback page with store and APK links.
- [x] 6.11 Wire `IFutureMatchReader` into the format-removal guard (3.3) and the sport-profile removal guard
  (4.6).
- [x] 6.12 Build the Flutter match screens (share sheet via `share_plus`; the App Links intent filter moves to 11.4,
  since it needs the `PublicBaseUrl` domain; `/m/{token}` already routes in the app):
  - create a post: sport, format, venue, Jalali date and time, duration, players brought, level range, gender,
    court and cost;
  - post details, join with a message, the host's request list with out-of-range badges;
  - invite from search and profile;
  - my matches (upcoming and past);
  - leave and cancel with the late-cancellation warning;
  - share through the Android share sheet, and App Links handling.
- [x] 6.13 Run the full test suite and fix until green. **Milestone: closed-beta candidate (search +
  matches).**

## 7. Chat [chat]

- [x] 7.1 Write failing integration tests for every scenario in `chat`.
- [ ] 7.2 (Needs a real phone on Iranian mobile networks; parked for the team.) Spike: connect the Flutter `signalr_netcore` client to `/hubs/realtime` over Iranian mobile networks.
  Record the result and the polling-fallback thresholds in `design.md`.
- [x] 7.3 Implement the `Conversation` aggregate (direct or match; members with request state, read cursor and
  mute) and the `Message` aggregate (unique client message id, deleted flag), with `messaging` schema
  persistence.
- [x] 7.4 Implement `IPlayerRelationshipReader` and `IBlockReader` in Host composition. Apply the
  message-request rules and the visibility check when a conversation is opened (D3, D8).
- [x] 7.5 Implement the commands:
  - open a direct conversation;
  - send a message (idempotent; 1000 characters, 500 for a request; 30 per minute; 20 new direct
    conversations per day);
  - accept or ignore a request; mark read; delete a message; mute and unmute.
- [x] 7.6 Implement the queries: inbox, requests, history (cursor of 50) and unread counts.
- [x] 7.7 Create match group conversations from match events once 2 players are accepted in a match with
  capacity above 2, and keep members in sync on accept, leave and remove.
- [x] 7.8 Deliver messages in real time through `IRealtimePublisher`, with presence from the host connection registry (Redis once a second instance exists, D8). Publish
  `messaging.message-received-offline` for push.
- [x] 7.9 Enforce block and inactive-member rules: no sending, hidden for the blocker, the blocked member's
  messages hidden in groups, «کاربر حذف‌شده» for deleted senders.
- [x] 7.10 Build the Flutter chat:
  - realtime client with reconnect and polling fallback;
  - inbox with conversations and requests tabs;
  - conversation screen: retry with client id, read receipts, deleted messages, safety notice;
  - match group chat, mute.
- [x] 7.11 Run the full test suite and fix until green.

## 8. Attendance, ratings and reliability [match-lifecycle › Attendance confirmation, player-ratings]

- [x] 8.1 Write failing integration tests for the attendance scenarios in `match-lifecycle` and every scenario
  in `player-ratings`.
- [x] 8.2 Implement the pure `AttendanceResolutionPolicy`, with unit tests for every outcome in the spec
  (Completed, Disputed, Unconfirmed, No-show, Contested).
- [x] 8.3 Record attendance answers on `Match`. Implement `MatchLifecycleWorker`, part 2: open attendance at the
  end time, and resolve when everyone has answered or after 72 hours. Publish the resolution events.
- [x] 8.4 Implement the `Rating` aggregate (eligibility, 7-day window, content, immutability) and
  `RatingRevealWorker` (pairwise reveal or window close), plus the rating-prompt and day-5 reminder events.
- [x] 8.5 Implement the pure `ReliabilityPolicy` with unit tests using the spec numbers. Implement the
  `PlayerReputation` read model per sport (stars, top tags, a level statement at a 60% majority, threshold
  3), updated from rating, attendance and late-cancellation events.
- [x] 8.6 Feed the reliability tier, public rating average and played-together signal into the profile view
  and `PartnerRankingPolicy`.
- [x] 8.7 Build the admin rating view (individual ratings, authors, private notes) and removal with a reason,
  recomputing the summaries.
- [x] 8.8 Build the Flutter screens:
  - attendance prompt: played, did not happen, flag no-shows;
  - rating: stars, up to 3 tags, level accuracy, private note;
  - reputation on the profile: new player, averages, tags, level statement, reliability tier.
- [x] 8.9 Run the full test suite and fix until green.

## 9. Reports and admin enforcement [trust-safety]

- [x] 9.1 Write failing integration tests for the report, queue, action, audit and dispute scenarios in
  `trust-safety`. Include one end-to-end test of ban propagation through Identity, Community, Messaging and
  Notifications.
- [x] 9.2 Implement the `Report` aggregate:
  - evidence snapshots of message text, post text, profile fields or a photo copy, read in-process from the
    owning contexts;
  - one open report per reporter and target;
  - an optional block in the same step.
- [x] 9.3 Implement the report queue query:
  - grouped by target;
  - priority for harassment and underage reports, and for 3 or more distinct reporters within 7 days;
  - target history: reports, actions, reliability, disputes in 90 days, private rating notes.
- [x] 9.4 Implement the `ModerationAction` commands:
  - warn, remove photo, hide post, delete message, suspend, lift, ban, correct gender;
  - each dispatched to its owning context and audited;
  - the player informed of warnings, suspensions and bans.
- [x] 9.5 Implement the admin audit log covering every admin action, with filters for admin, target, action
  type and date.
- [x] 9.6 Build the admin screens: report queue, target detail with evidence and history, action dialogs,
  audit log, disputed matches.
- [x] 9.7 Build the Flutter report flow from a profile, message, post or photo (reason, details, optional block
  in the same step) and a "my reports" status list.
- [x] 9.8 Run the full test suite and fix until green.

## 10. Notifications [notifications]

- [x] 10.1 Write failing integration tests for every scenario in `notifications`.
- [x] 10.2 Implement the Notifications context:
  - `Notification` aggregate: inbox, read state, 90-day retention job;
  - `NotificationPreferences`: categories and quiet hours;
  - `DeviceToken` entity with register and unregister endpoints;
  - `notifications` schema persistence.
- [x] 10.3 Implement `NotificationEventCatalog`: each event's category, channels, and Persian template with
  Persian digits and Jalali dates. Add CAP subscribers for every event in the catalog table, deduplicated
  on `(source_event_id, recipient_id)`.
- [x] 10.4 Port the FCM gateway (FirebaseAdmin, credentials from configuration, invalid-token revocation) and
  apply category toggles, always-on account notices, and quiet hours with their exemptions.
- [x] 10.5 Implement `ReminderWorker` (2 hours before start). Deliver saved-search digests, staleness reminders,
  attendance prompts and rating prompts.
- [x] 10.6 Push new inbox items and unread counts to online users through `IRealtimePublisher`.
- [x] 10.7 Revoke device tokens on sign-out, suspension, ban and deletion.
- [x] 10.8 Build the Flutter notification features:
  - firebase_messaging, with `google-services.json` supplied at build time and never committed;
  - token registration and refresh;
  - push routing to deep links;
  - inbox screen, preferences and quiet-hours screen.
- [x] 10.9 Build the admin usage dashboard: sign-ups, active players, posts, matches, completion rate, reports.
- [x] 10.10 Run the full test suite and fix until green.

## 11. Launch readiness

- [ ] 11.1 Run the venue import for every province, review the candidates, and bulk-approve them, so the catalog
  covers the country before launch.
- [x] 11.2 Security pass:
  - review the rate-limit configuration;
  - check that logs mask phone numbers and codes;
  - add authorization tests for every admin endpoint;
  - verify the production guard.
- [x] 11.3 (Measured 2026-10-23 with `RALLYTO_PERF=1`: p50 97 ms, p95 144 ms over 100 searches through the API; no index changes needed.) Performance check: seed synthetic data (50,000 availability windows, 10,000 open posts). Confirm
  partner search stays under 300 ms at p95, and tune indexes.
- [ ] 11.4 Prepare the Android release:
  - signing on the owner's machine;
  - `version: x.y.z+N` numbering as in AsanRezerve;
  - Firebase config injected at build time;
  - App Links verification file once the domain exists.
- [ ] 11.5 Provision the server and domain (waiting on the product owner). Then set `PublicBaseUrl`, enable
  `deploy.yml` with database backup and smoke checks, and deploy to staging.
- [ ] 11.6 Run a closed beta with a few partner clubs and fix what it finds.
- [ ] 11.7 Publish to Cafe Bazaar and Myket, and link the direct APK.

## 12. Brand, rename and landing site (Rallyto)

- [x] 12.1 Rename the product from TennisYar to Rallyto (رالیتو, rallyto.ir) everywhere: user-facing text, .NET
  namespaces and projects, the Dart package (`rallyto_app`), Android/iOS ids (`ir.rallyto.app`), configuration,
  CAP topics, folders (`rallyto-app`, `rallyto-admin`) and docs. The repository root folder keeps its old name.
- [x] 12.2 Design the logo (the rally loop) with one source, `branding/mark.json`, and generate every icon, adaptive
  icon, splash image, notification icon, favicon and store icon from it (`branding/build_brand.py --render`).
- [x] 12.3 Player app: `BrandMark`/`BrandTile` painted from the brand geometry, an animated launch splash that
  continues the native splash (one rally turn, then the wordmark; skipped for reduced motion), native splash and
  adaptive icons wired, the sign-in art showing the mark.
- [x] 12.4 Admin panel: the brand mark in the sidebar and on sign-in, favicons.
- [x] 12.5 Landing site (`rallyto-landing`, Astro, static): home page with the court hero, one page per sport with the
  catalog's levels, FAQ, privacy and terms; SEO metadata, structured data, sitemap, share image; unit tests,
  built-site contract tests and Lighthouse thresholds; CI job.
- [ ] 12.6 Before the site goes live: store links, a reviewed privacy policy with retention periods, contact details
  and legal entity, and real clubs in the catalog (11.1). See `rallyto-landing/README.md`.
