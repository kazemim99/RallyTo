## Context

Rallyto starts as an empty repository. The proposal defines the product: partner matching for tennis, padel
and badminton players in Iran, matched by city, club and time window, never by a player's own location. It also
records the confirmed product decisions:
- 18+ only;
- first chat contact arrives as a message request;
- optional same-gender visibility;
- stars and tags only, no written reviews;
- free MVP, launched nationwide, with a venue catalog for all of Iran imported from Google Places;
- push through Firebase Cloud Messaging;
- the admin reviews reports, so there are only two roles, Player and Admin.

The technical reference is AsanRezerve (`c:\Repos\Booking`). Everything below about AsanRezerve was read from
its code on 2026-10-23, not from its docs. The facts that matter here:

- **Modular monolith.** A single ASP.NET Core host composes bounded contexts. Each context is Domain /
  Application / Infrastructure / Api projects over shared `Core.Domain`, `Core.Application` and
  `Infrastructure.Core` building blocks.
- **Building blocks.** The shared projects provide `AggregateRoot<TId>`, `ValueObject`, `Result<T>`, a
  MediatR pipeline (Logging → Validation → Authorization → Idempotency → Performance → Transaction →
  Caching), CAP over a PostgreSQL outbox with the in-memory transport, and HybridCache over Redis.
- **Phone OTP.** The `PhoneVerification` aggregate uses a 4-digit code valid 5 minutes, allows 5 attempts and
  then blocks for 1 hour, with a 60 s resend cooldown and 3 sends per 10 minutes. Only the code's hash is
  stored, in PostgreSQL. SMS goes through `ISmsNotificationService` (MeliPayamak). Sign-in issues a JWT plus
  a rotating refresh token.
- **SignalR.** `/hubs/notifications` exists, but no client uses it; the apps poll REST.
- **Push.** FCM is sent through `IFirebaseMessagingGateway`, and device tokens are registered with
  `POST /DeviceTokens`. Firebase client config is not committed to the repository.
- **Flutter app.** `lib/core` + `lib/features/<x>/{data,domain,presentation}`, flutter_bloc,
  get_it + injectable, dio + retrofit, go_router. Strings are in `app_strings.dart`, the locale is fixed to
  `fa_IR`, layout is RTL, the font is Vazir, and dates use `shamsi_date`.
- **Admin panel.** Vue 3 + ant-design-vue + Pinia + vue-i18n.
- **Integration tests.** `WebApplicationFactory` + Testcontainers PostgreSQL, a `TRUNCATE … CASCADE` reset
  before each test, and a test authentication handler.
- **Known gaps** that Rallyto must not copy:
  - the transaction behavior commits whichever unit of work was registered last;
  - database naming is mixed (`user_management` snake_case vs `ServiceCatalog` PascalCase);
  - package versions are set per project (central package management covers tests only);
  - dead code sits in `Core.Domain` but is excluded from compilation.

Stakeholders: the product owner, players, admins, and later the clubs.

## Goals / Non-Goals

**Goals:**

- Ship the twelve capabilities in the proposal as one Android app and one admin panel, backed by a single
  .NET host. Delivery comes in vertical slices, each runnable and tested.
- Reuse AsanRezerve's architecture, libraries, client structure and operations so the same team can run both
  products, and fix its known gaps from the first commit.
- Make privacy and safety structural, not bolted on:
  - no player geolocation;
  - phone numbers never leave the Identity context;
  - blocks, bans and gender visibility are enforced in every read path.
- Keep every rule that decides who sees whom, who may rate whom, and how reliability is computed in a pure,
  unit-tested policy class.

**Non-Goals:**

- Court booking, payments, coach marketplace, leagues/ladders/tournaments, computed levels (Elo/WTN), score
  tracking, paid tiers, web player app, iOS store release.
- Horizontal scaling. The MVP runs one API instance. The design keeps scale-out possible (stateless API,
  background jobs safe on several instances, an optional SignalR Redis backplane) but does not build it.
- A general-purpose search engine. PostgreSQL is enough at Tehran scale.

## Decisions

### D1. Modular monolith on .NET 10, building blocks forked from AsanRezerve

One host process, `Rallyto.Host`, composes the bounded contexts in-process. The AsanRezerve building blocks are
copied into `src/BuildingBlocks/` and renamed to `Rallyto.*`:
- `Core.Domain`, `Core.Application`, `Infrastructure.Core`;
- the security, observability and API middleware projects;
- the MeliPayamak SMS adapter.

The copy drops the code that AsanRezerve excludes from compilation, plus everything about payments and booking.
The source commit is recorded in `docs/BUILDING_BLOCKS_ORIGIN.md`.

- *Alternative: extract shared NuGet packages used by both products.* Rejected for now. Versioning and
  releasing packages slows both teams down before the shared surface is known. Extraction stays possible once
  the forked code stops changing.
- *Alternative: clone the AsanRezerve repository and delete what is not needed.* Rejected. It would bring 17
  migrations, booking/payment/ledger code and the known gaps along with it.
- *Alternative: microservices.* Rejected. The team is small, the scale is one city, and AsanRezerve already
  proved the monolith operationally.

### D2. Five bounded contexts, one PostgreSQL schema each

| Context | Schema | Aggregates (roots in bold) | Owns |
|---|---|---|---|
| **Identity** | `identity` | **UserAccount** (owns RefreshToken), **PhoneVerification**, **BannedPhone** | Phone number (E.164), roles (Player, Admin), account status (Active, Suspended until, Banned, Deleted), sessions |
| **Catalog** | `catalog` | **Sport** (owns PlayFormat, LevelTierDescription), **Province**, **City**, **Venue** (owns VenueSport), **VenueCandidate** | Reference data: sports, formats, the five level tiers' wording per sport, Iran's provinces and cities, clubs and the sports/courts they offer, imported candidates and their review state |
| **Community** | `community` | **PlayerProfile** (owns SportProfile, HomeVenue), **Availability**, **Match** (owns MatchParticipant, AttendanceAnswer), **SavedSearch**, **Rating**, **PlayerReputation**, **Block**, **Report**, **ModerationAction** | Everything a player does with other players, except messages |
| **Messaging** | `messaging` | **Conversation** (owns ConversationMember), **Message** | Conversations, message requests, messages, read cursors |
| **Notifications** | `notifications` | **Notification**, **NotificationPreferences**, DeviceToken (plain entity, as in AsanRezerve) | Notification inbox, push delivery, device tokens, preferences, quiet hours |

Why these boundaries:

- **Community is deliberately large.** Partner search joins profiles, sport levels, availability windows,
  matches (to find busy players), blocks and reputation in one SQL query. Splitting these across schemas would
  force denormalised read models and eventual consistency into the hottest path of the product.
  AsanRezerve's ServiceCatalog shows that a context of this size is manageable.
- **Messaging is separate.** It has a different write volume, retention and scaling profile, and a separate
  schema allows its own retention jobs and later extraction.
- **Notifications is separate.** In AsanRezerve notifications live inside ServiceCatalog. Here many contexts
  produce notifications, so a separate context consuming integration events keeps producers free of delivery
  concerns.
- **Identity alone holds the phone number.** Other contexts only know the `UserId`.
- **Gender and birth date are profile data** and live in `PlayerProfile` (Community). The 18+ gate runs when
  the profile is created; an account without a completed profile can do nothing but finish onboarding.

### D3. Cross-context rules

- **No transaction spans two contexts.** Each command handler saves through its own context's unit of work.
- **Asynchronous facts travel as integration events.** They go through CAP: PostgreSQL outbox written in the
  producer's transaction, in-memory transport, consumer group `rallyto`. Topics are named
  `rallyto.<context>.<event>`, for example `rallyto.community.match-confirmed`. Consumers are idempotent
  on the event id.
- **Synchronous reads use in-process query interfaces.** Each interface is declared in the consumer's
  Application layer and implemented in `Rallyto.Host/Composition`, the same pattern as AsanRezerve's
  `InProcessProviderInfoService`:
  - Messaging asks Community `IPlayerRelationshipReader` (do these two players share a confirmed or played
    match?) and `IBlockReader`.
  - Every context asks Identity `IAccountStatusReader`, cached in HybridCache and evicted on status-change
    events.
- **Account lifecycle events fan out:**
  - `identity.account-suspended`, `identity.account-banned` and `identity.account-deleted` make Community hide
    the profile and cancel future matches;
  - Messaging marks the member as left;
  - Notifications revokes the device tokens.

### D4. One `Match` aggregate for play posts and direct invitations

A play post is a `Match` with `Visibility = Public` and open spots. A direct invitation is a `Match` with
`Visibility = Private` whose invitees start in the `Invited` state. Both share one participant model, one
capacity rule, one attendance flow and one rating eligibility rule.

**Match states:**
- `Open`: public, accepting join requests.
- `Pending`: private, waiting for invitees.
- `Confirmed`: the match is full, or the host confirmed early with at least 2 accepted players. A non-full
  match that has at least 2 accepted players at start time is confirmed automatically.
- `Completed`, `Disputed`, `Unconfirmed`: outcomes of attendance resolution.
- `Cancelled`: by the host, or a private match whose invitees all declined.
- `Expired`: start time reached with fewer than 2 accepted players.

**Participant states:** Host, Invited, Requested, Accepted, Declined, Withdrawn, Left, Removed.

**Capacity** is players-per-side × 2 from the sport's format: tennis/badminton singles = 2, doubles = 4,
padel = 4, squash = 2 (singles only). Concurrent join acceptances are serialised by optimistic concurrency on PostgreSQL `xmin`, as
AsanRezerve does for Booking, so a match can never be overfilled.

**Late cancellation.** An accepted participant who leaves, or a host who cancels a confirmed match, less than
`Play:LateCancellationHours` (default 12) before the start gets a late-cancellation record.

**Attendance** opens at the end time and closes 72 h later. Each accepted participant answers "played" or "did
not happen" and may flag individual no-shows. `AttendanceResolutionPolicy` is pure and unit-tested:

| Answers | Outcome |
|---|---|
| At least one "played" and no "did not happen" | Completed |
| A participant flagged by someone else who did not answer "played" | No-show for that participant |
| "Played" vs "did not happen" | Disputed: no ratings, no reliability effect, visible to admins |
| No answers | Unconfirmed: neutral |

- *Alternative: separate PlayPost, Invitation and Match aggregates.* Rejected. Three copies of participant
  logic, and state that has to be kept in sync between them.

### D5. Availability model and time handling

- **Concrete moments are `timestamptz` in UTC.** That covers match start/end and one-off availability. The API
  speaks ISO 8601 with an offset, and clients render them as Jalali dates in Asia/Tehran.
- **Recurring windows are wall-clock concepts.** "Saturdays 18:00–24:00" is stored as weekday (Iranian week,
  Saturday = 0) + local start/end minute (0–1440) + `valid_from`/`valid_until`.
  - Iran has used a fixed UTC+03:30 offset since it abolished DST in 2022. Conversions still go through
    `TimeZoneInfo("Asia/Tehran")`, so a future rule change only needs updated tzdata.
- **Window rules:**
  - 30-minute granularity, 60 minutes minimum.
  - A window may end at 24:00 but not cross midnight in the MVP. A late-night player creates two windows.
  - A window names 1–3 clubs and one sport.
- **Stale availability** is the main quality risk in partner apps (players who quit still show up). A
  recurring window is paused automatically if not reconfirmed within 30 days; a notification asks "still
  available?" first. One-off windows expire after their date.
- `TimeProvider` is injected everywhere so tests can use `FakeTimeProvider`. AsanRezerve's `IDateTimeProvider`
  was not ported; the building blocks were adapted to `TimeProvider` (see `docs/BUILDING_BLOCKS_ORIGIN.md`).

### D6. Partner search in PostgreSQL with a pure ranking policy

**Input:**
- sport and city;
- optional clubs;
- a date or a set of weekdays, plus a time window;
- level tier range, partner gender, format;
- what to return (posts, players or both), and paging.

**Filtering is SQL (EF Core LINQ) over the `community` schema:**
- **Posts:** public `Open` matches with free spots, at the requested clubs, overlapping the requested time.
  The host's partner-gender preference must accept the searcher's gender.
- **Players:** active availability windows for the sport, at the requested clubs, overlapping by at least 60
  minutes. A weekday window matches a requested date when its weekday matches and the date is within its
  validity.
- **Always excluded:**
  - the searcher;
  - players blocked in either direction;
  - accounts that are not active;
  - profiles hidden from the searcher by same-gender visibility;
  - players without a profile for that sport;
  - players who already have a confirmed match overlapping the slot.

**Ranking** happens in memory over the pre-filtered candidates (capped at 500, newest activity first).
`PartnerRankingPolicy` is a pure function. Inputs: level closeness, overlap ratio, reliability tier, rating
average (only when shown publicly), recent activity, and whether the two played together before. Weights are in
configuration. Ties break on last activity, then id.

**Indexes:** `availability (sport_id, status, weekday)`, `availability_venue (venue_id)`,
`match (sport_id, status, starts_at)`, `match_venue`, `block (blocker_id, blocked_id)` and its reverse.

**Saved searches** are evaluated when `availability-published` or `match-published` events arrive. Each saved
search raises at most one alert per 6 hours, as a digest when several items match.

- *Alternative: Elasticsearch, Meilisearch or OpenSearch.* Rejected. One more stateful service to run, with a
  sync pipeline, and none of its strengths (text relevance, huge corpora) apply.
- *Alternative: PostGIS.* Not needed, because no player coordinates exist. Club coordinates are display-only.

### D7. Ratings and reliability

- **Eligibility.** A `Rating` is unique per (match, rater, ratee). It is allowed only when both rater and ratee
  counted as "played" in a Completed match, and only within 7 days of resolution.
- **Content.** 1–5 whole stars; tags from a fixed list (on time, friendly, fair line calls, good rally, good
  sportsmanship); level feedback (lower than declared / about right / higher); an optional private note that
  only admins see.
- **Double-blind reveal.** A rating is stored hidden. It becomes visible when the counterpart has rated, or
  when the window closes, whichever comes first. `RatingRevealWorker` closes the window.
- **Reputation summary.** `PlayerReputation` is a read model updated from rating and attendance events. Each
  piece appears only after 3 revealed ratings:
  - star average;
  - top tags;
  - level-feedback distribution.
- **Reliability** comes from the last 20 resolved commitments: played / (played + no-shows +
  0.5 × late cancellations).
  - It is shown as a tier: New (fewer than 3 resolved), High (≥ 0.90), Good (≥ 0.75), Low.
  - The raw number is never shown, to avoid shaming and score-gaming.
  - Disputed and Unconfirmed matches are excluded.

*As built:* there is no persisted `PlayerReputation` read model. Reputation and reliability are computed on
read by the pure `ReputationPolicy` and `ReliabilityPolicy`, from source rows:
- revealed, non-removed ratings, indexed by `(ratee_id, sport_id)`;
- participation outcomes and late cancellations.

An event-maintained read model would be stale inside the very unit of work that changes its inputs, because
domain events are dispatched before the save. It would also need replays whenever an admin removes a rating.
Search loads the signals for its candidate set in three batched queries. If search latency calls for it, a
cached or persisted projection can be added behind `IReputationReader` without touching the policies.

AsanRezerve's `Review` queues every review for admin moderation before publication. That is not copied here:
there is no text to moderate, so ratings publish on reveal. Abuse is handled through reports.

### D8. Chat over REST + SignalR, with FCM for background delivery

- **Sending.** A message is sent with `POST /api/v1/conversations/{id}/messages`, carrying a client-generated
  message id. The request is idempotent, and the normal validation, authorization and rate-limit pipeline
  applies.
- **Delivery.** The message is persisted, then pushed over SignalR to the other members' `user_{id}` groups.
  Members with no live connection get an FCM push. Presence is the connection count per user, kept by the
  host's in-process `ConnectionRegistry` while there is one instance; it moves to Redis together with the
  SignalR backplane when a second instance is added.
- **History** uses cursor pagination. The read state is a per-member `LastReadMessageId` cursor; the MVP has
  no per-message receipts.
- **Message requests.**
  - A direct conversation between players who do not share a confirmed or played match, where the recipient
    has not already accepted, starts as a request.
  - The sender can send one message of at most 500 characters until the recipient accepts.
  - Ignoring a request is silent: the sender is not told.
  - Blocking from the request screen is one tap.
- **Match chats.**
  - A singles match uses the direct conversation between the two players, accepted automatically.
  - A match with more than 2 accepted players gets a group conversation, and its membership follows
    participant events.
  - *As built:* the group is created once the roster holds the host and at least two accepted players. Every
    participant event (answer, confirm, leave, remove) re-reads the roster through the in-process
    `IMatchRosterReader` and reconciles the members, so repeated or out-of-order CAP deliveries converge. A
    member who leaves keeps history up to `LeftAfterSeq`; a member accepted again rejoins.
- **Ordering and read state (as built).** Messages carry a database identity `seq`. The read cursor
  (`LastReadSeq`) and the history cursor are sequence numbers, so ordering never depends on clock resolution.
- **Limits.** Text is at most 1000 characters, with no attachments in the MVP.
  - *As built:* messages per minute use the built-in limiter's `chat-send` policy.
  - The 20 new direct conversations per rolling 24 h are counted in the open handler, not through a
    per-request rate limit. Reopening an existing conversation must not use up the quota.
- **Inactive accounts (as built).** Messaging consumes the Identity status events and flags the member's
  rows (`account_inactive`). Nobody can send to a flagged member in a direct conversation. Their own sends are
  already stopped by `ActiveAccountMiddleware`.
- **Deleting a message (as built).** The body is cleared for everyone. The original text survives only in a
  report filed earlier (section 9).
- **Errors (as built).** A block, a deleted counterpart and a left match chat all return the same 403
  `CANNOT_REPLY`, so a block is never revealed. A non-member gets 404 `CONVERSATION_NOT_FOUND`.
- **Hub.** One host-level hub, `/hubs/realtime`, carries chat and notification events for both contexts.
  Contexts publish through an `IRealtimePublisher` building-block interface, so none of them references
  SignalR directly. The hub authenticates with the `access_token` query string, as AsanRezerve's
  `SignalRAccessTokenExtractor` does.
- **Flutter client.** The app connects with the `signalr_netcore` package while in the foreground and falls
  back to polling if the hub cannot connect.
- **Retention.** Chat history is kept for as long as the account exists. When an account is deleted, its
  messages remain for the other party but show as "deleted user". A report snapshots the reported message, so
  moderation works after an edit or deletion.

- *Alternative: polling only, like AsanRezerve's inbox.* Rejected. Chat that arrives 30 s late feels broken.
- *Alternative: FCM data messages as the only real-time channel.* Rejected. No delivery guarantee, and no
  in-app "typing/read" path.

### D9. Notifications context

- **Producers** publish domain facts as CAP integration events. Examples: invitation received, join request
  received or answered, match confirmed or cancelled, match reminder due, attendance open, rating window open,
  saved-search hit, message received while offline, moderation action.
- **`NotificationEventCatalog`** maps each event code to:
  - its category;
  - its default channels (InApp always, Push per preference);
  - its Persian template.
  The idea comes from AsanRezerve's catalog.
- **Every notification is persisted** in the inbox first; push is best-effort on top. Duplicates are
  prevented by a unique `(source_event_id, recipient_id)` key, because CAP delivers at least once.
- **Preferences** cover push on/off per category and quiet hours (default 23:00–08:00 Tehran; match reminders
  ignore quiet hours).
- **Device tokens** follow AsanRezerve's `DeviceToken`: a plain entity with a unique token, platform and
  revocation, and `POST/DELETE /api/v1/device-tokens`.
- **Firebase.** A separate Firebase project for Rallyto. `google-services.json` is supplied at build time
  and not committed, like AsanRezerve.
- **Timed notifications** (match reminders 2 h before start, attendance prompts, rating prompts) come from
  `BackgroundService` workers. There is no Hangfire, as in AsanRezerve.
- *As built:*
  - **Chat pushes.** These are stored as notifications with `in_inbox = false`. The same unique key then
    deduplicates them, but they never appear in the inbox.
  - **Reminders and venue-hidden notices** have no single source event. They use an id derived from the match
    (`MD5(source:discriminator)`), so a reminder is sent once however often `NotificationsMaintenance` runs.
  - **Account notices** (warning, suspension, gender correction) ignore the category switches but respect quiet
    hours. The exemptions from quiet hours are only match reminders and the cancellation of a match starting
    within 12 hours.
  - **Sign-out.** The app unregisters its token with `DELETE /device-tokens` before signing out. Suspension,
    ban and deletion revoke every token from the Identity events. A suspended player is told the end date
    and reason first.
  - **The FCM gateway** skips sends when no credentials are configured, and the production guard refuses to
    start without them.
  - **SignalR** uses the REST API's JSON settings (string enums, unescaped Persian).

### D10. Identity and access

- **Phone OTP** copies AsanRezerve's `PhoneVerification` rules (4 digits, 5 minutes, 5 attempts then a 1 h
  block, 60 s cooldown, 3 sends per 10 minutes, hash only) and its two rate-limiting layers.
  - There is one endpoint pair, `POST /api/v1/auth/otp/send` and `POST /api/v1/auth/otp/verify`, with no
    customer/provider split.
  - The Android app autofills the code through `smart_auth`, like the AsanRezerve apps.
  - `OTP_SANDBOX_CODE` exists for development and testing, and the production configuration guard refuses
    to start with it set.
- **Tokens.** The access token lives 60 minutes (AsanRezerve: 24 h). The refresh token lasts 30 days and
  rotates on every use; reusing a rotated token revokes the whole token family. An `ActiveUser` policy checks
  the cached account status on every request, so a suspension or ban takes effect within seconds, not at
  token expiry.
- **Roles** are Player (default) and Admin. The admin also reviews reports, so there is no moderator role. The
  admin panel signs in with an email and a password (product owner's decision, 2026-10-24). Players keep the
  SMS code; a phone sign-in never grants Admin.
  - The panel account comes from `Identity:InitialAdmin:Email/Password`: user-secrets locally, `ADMIN_EMAIL` /
    `ADMIN_PASSWORD` in the server's `.env`. It is never in the repository.
  - A seeder creates the account at startup and resets its password when the configured one changes.
  - Passwords are PBKDF2-SHA256 (210,000 iterations, random salt, constant-time compare).
  - Five wrong passwords lock password sign-in for 15 minutes, and the endpoint has its own rate limit.
  - Wrong email and wrong password give one generic answer.
  - Further admins can still be granted the role by an admin.
- **Local sign-in code.** Development uses the sandbox code `2222` (`appsettings.Development.json`). The
  production guard refuses to start with any sandbox code, so a deployed server always sends real SMS.
- **Account deletion.**
  - The status becomes Deleted and all refresh tokens are revoked.
  - An `account-deleted` event makes Community anonymise the profile and cancel future matches.
  - The phone number is released for a new registration, unless the account was banned. For banned accounts,
    a peppered SHA-256 of the phone number is kept in `BannedPhone` to stop ban evasion.

### D11. Privacy and safety enforcement

- **Phone numbers** exist only in `identity`. Every other context uses `UserId`. Serilog's
  `SensitiveDataMaskingEnricher` (forked) masks phone numbers and OTP codes.
- **Age** is shown as a range (18–24, 25–34, 35–44, 45–54, 55+). Birth date never leaves Community.
- **Gender** is set once at onboarding. After that it changes only through an admin command, which is
  audited.
- **Same-gender visibility.** `PlayerProfile.Visibility` is Everyone or SameGender. One
  `VisibilityPolicy.CanSee(viewer, subject)` is applied in search, profile view, post listing and join, and
  message-request creation.
- **Blocking.** `Block` is mutual in effect: neither player sees the other in search, posts, profiles or
  chat. Existing future matches between them stay, but the blocked player can be removed by the host or can
  leave without a late-cancellation penalty.
- **Reports.** Targets are a player, a message, a match or a photo. A report stores an evidence snapshot.
- **Moderation.** An admin works the report queue in the admin panel. It supports these actions: warn,
  remove photo, hide post, suspend (until a date) and ban. Suspend and ban go to Identity as commands; Identity then emits the status event of
  D3.
- **Architecture tests** (NetArchTest) fail the build if any context other than Identity references the phone
  number type, or if a query handler in Community returns players without going through `VisibilityPolicy`.

### D12. API, persistence and code conventions

- **API.** Paths follow `api/v{version}/…` with Asp.Versioning and Swagger. The fallback policy requires
  authentication. Health probes are anonymous. AsanRezerve's `ApiResponseMiddleware` envelope
  (`{success, data, metadata}`) and exception mapping are kept, so the Flutter API client and error handling
  port unchanged.
- **Persistence.**
  - There is one DbContext per context, all on one connection string.
  - `EFCore.NamingConventions` applies `UseSnakeCaseNamingConvention()` in every context, so tables, columns
    and schemas are snake_case.
  - Audit fields and UTC conversion come from the forked building blocks.
  - Aggregates that see concurrent writes (`Match`, `Conversation`) use an `xmin` concurrency token.
  - Migrations run at startup in a fixed order: identity, catalog, community, messaging, notifications.
    They are idempotent.
- **Transactions.** AsanRezerve's generic `TransactionBehavior` is not copied, because it commits whichever
  unit of work was registered last. Each context registers a marker unit of work (`ICommunityUnitOfWork`,
  etc.), and handlers call `SaveAndPublishEventsAsync` on their own context's marker, the pattern AsanRezerve
  had to adopt anyway.
- **Caching.** Catalog reference data (sports, cities, venues) is cached through the forked `CachingBehavior`
  allowlist. The allowlist test is carried over. Search results and anything player-specific are never
  cached.
- **Media.** A profile photo is decoded and re-encoded with SkiaSharp, which also drops EXIF metadata such as GPS
  position. It is stored on a mounted volume behind
  `IFileStorage` (AsanRezerve stores uploads under `wwwroot`) and served with an unguessable key.
- **Background work** uses `BackgroundService` + `PeriodicTimer`. Each job holds a PostgreSQL advisory lock
  (`pg_try_advisory_lock`) while it runs, so with a second instance only one copy runs at a time. This is simpler
  than `FOR UPDATE SKIP LOCKED` and lets a job save through its context's unit of work and CAP outbox. Workers can be
  switched off with `Workers:Enabled=false`; the integration tests run the jobs by hand. The jobs are:
  - `MatchLifecycleWorker`: auto-confirm or expire at start, open attendance at end, resolve 72 h later;
  - `RatingRevealWorker`;
  - `AvailabilityStalenessWorker`;
  - `ReminderWorker`;
  - `SavedSearchDigestWorker`.

### D13. Clients

- **Flutter app** `rallyto-app`, structured like AsanRezerve's customer app.
  - Core folders: `lib/config/{routes,theme}`, and `lib/core/{api,auth,di,push,realtime,storage,utils,widgets,constants}`.
  - Feature folders: `lib/features/{auth,onboarding,profile,availability,search,matches,chat,ratings,notifications,safety}/{data,domain,presentation}`.
  - The packages are AsanRezerve's, plus `signalr_netcore`.
  - Strings live in `app_strings.dart`, the locale is `fa_IR`, and the font is Vazir. Jalali and Tehran-time
    helpers are ported from `lib/core/utils/`.
  - The auth interceptor keeps a single shared refresh future, because refresh tokens are one-use.
- **Admin panel** `rallyto-admin`, structured like `asan-rezerve-admin`: Vue 3, ant-design-vue, Pinia,
  vue-i18n with the `fa` default, antd `fa_IR`, and `useRTL`. It uses OTP login.
- **Share links.** A public play post has an unguessable share token. `https://<domain>/m/{token}` opens the
  app through Android App Links, or a fallback web page with store links. Sharing posts into existing club
  Telegram and WhatsApp groups is the main acquisition loop.

### D14. Testing strategy

- **Integration tests** (`tests/Rallyto.Host.IntegrationTests`) port AsanRezerve's harness:
  - a `WebApplicationFactory` host;
  - a shared Testcontainers PostgreSQL per process, plus Redis;
  - `DatabaseReset` truncating everything except migration history and `cap` before each test;
  - `IntegrationTestAuthenticationHandler` with a per-test user context;
  - fakes for SMS, FCM and `TimeProvider`.
- **What integration tests cover:** each capability's workflows, state transitions, persistence and API
  contracts. Examples: OTP sign-in, post, join, accept, confirm, attendance, rating, reveal; message request,
  accept, block; ban propagating across contexts.
- **Unit tests** per Domain project cover the pure policies: overlap, visibility, ranking, attendance
  resolution, reliability, rating reveal, age gate and capacity.
- **Architecture tests** cover layer rules, the phone-number boundary, the cache allowlist and the
  per-context unit-of-work rule.
- **Clients:** Flutter tests mirror `lib/` as in AsanRezerve, and the admin panel uses Vitest.
- **CI** runs all of it on every push.

### D15. Nationwide venue catalog imported from Google Places

- **Cities.** Iran's 31 provinces and their cities are seeded from a static file of the official divisions,
  with Persian names.
- **Candidate import.** Clubs come from an offline console tool, `tools/Rallyto.VenueImport`.
  - **Who runs it:** an admin.
  - **Where:** on a machine outside Iran, with a Google Cloud project that has a non-Iranian billing
    account, because Google Maps Platform does not serve Iranian accounts or IP addresses.
  - **What it queries:** Places API (New) Text Search, once per city × sport keyword. Keywords include
    «باشگاه تنیس», «زمین تنیس», «پدل», «سالن بدمینتون», «اسکواش».
  - **Where results go:** `POST /api/v1/admin/venue-candidates/import`, which accepts them as
    **VenueCandidate** records, never as live venues.
- **Deduplication.** Candidates are matched by Google `place_id` against existing venues, earlier candidates
  and earlier rejections, so re-running the import is safe and rejected places do not come back.
- **Admin review.** An admin approves a candidate (choosing the sports and court details), merges it into an
  existing venue, or rejects it. Candidates of one city can be approved in bulk with the same sports; court
  details stay optional. Only approved venues are visible to players. Each venue keeps the `place_id` as its
  source reference.
- **Manual entry.** Clubs Google does not list are added by an admin by hand.
- **No player or club input.** Players and clubs cannot add or edit venues; the Rallyto team owns the whole
  catalog. The product is for finding practice partners, not for running clubs.
- **Pluggable source.** The import tool has a source interface, so OpenStreetMap or the Neshan Search API
  can be added as another adapter without changing the catalog.

- *Alternative: compile the list by hand.* Rejected by the product owner: it does not scale to the whole
  country.
- *Alternative: query Google at runtime from the API.* Rejected. It would fail from servers in Iran, and it
  would make availability depend on a sanctioned foreign service.

### D16. Repository and delivery

- **Layout:**
  - `src/BuildingBlocks/*`;
  - `src/Contexts/{Identity,Catalog,Community,Messaging,Notifications}/Rallyto.<Ctx>.{Domain,Application,Infrastructure,Api}`;
  - `src/Host/Rallyto.Host`;
  - `tests/*`, `rallyto-app/`, `rallyto-admin/`.
- **Build configuration.** A root `Directory.Build.props` (net10.0, nullable, implicit usings,
  `TreatWarningsAsErrors`, analyzers) and a root `Directory.Packages.props` (central package management for
  `src/` and `tests/`), plus `global.json`.
- **Compose:** `docker-compose.yml` for dev (postgres, redis, seq, pgadmin, api) and `docker-compose.prod.yml`
  for production (GHCR images).
- **GitHub Actions:**
  - `ci.yml`: build, unit, integration and architecture tests, Flutter analyze/test, admin Vitest;
  - `deploy.yml`: on `master`, back up the database, compose pull and smoke-check on the server, as in
    AsanRezerve;
  - `android-release.yml`: optional; signed APKs are built on the owner's machine, as in AsanRezerve.

### Deviations from AsanRezerve

| Area | AsanRezerve | Rallyto | Why |
|---|---|---|---|
| Runtime | .NET 9 | .NET 10 LTS | .NET 9 support ends 2026-11-10; .NET 10 is supported to 2028-11 |
| Package versions | Per `.csproj`; central management for tests only | Root `Directory.Packages.props` + `Directory.Build.props` (nullable, warnings as errors) | One version per package; the compiler enforces what AsanRezerve enforces in only one project |
| Database naming | Mixed (`user_management` snake_case, `ServiceCatalog` PascalCase) | snake_case everywhere via `EFCore.NamingConventions` | Consistency; idiomatic PostgreSQL |
| Notifications | Inside ServiceCatalog; handlers call `INotificationRaiser` | Own context, consuming CAP integration events | Producers in four contexts |
| Transaction behavior | Generic behavior commits the last registered unit of work | Per-context unit-of-work markers only | Removes a known bug class |
| SignalR | Hub inside ServiceCatalog; clients poll | Host-level hub; the app uses it for chat and notifications | Real-time chat is a core feature |
| Access token lifetime | 24 h | 60 min + `ActiveUser` check | Suspensions and bans must take effect immediately |
| Admin sign-in | Password | Phone OTP + role | One authentication path, no passwords |
| Object mapping | AutoMapper 15 in ServiceCatalog | No AutoMapper; explicit mapping and EF projections | AutoMapper 15 needs a commercial licence; AsanRezerve's UserManagement already works without it |
| Review moderation | Every review waits for admin approval | Ratings publish on double-blind reveal; abuse goes through reports | Stars and tags only, nothing to pre-moderate |
| MediatR | 13.x (licence key required from 13.0) | 12.5.0, the last Apache-2.0 release, pinned | No licence; the product owner chose the free version |
| Rate limiting | Two layers: AspNetCoreRateLimit + the built-in limiter | The built-in ASP.NET Core limiter only: a global per-user/IP window plus named policies | One mechanism to configure and test; distributed limits are not needed on one instance |
| Shared web projects | `AsanRezerve.API`, `.Infrastructure.Security`, `.Infrastructure.Observability` | One `Rallyto.Infrastructure.Web` project | Fewer projects for the same code; the three were always used together |
| API versioning | `Microsoft.AspNetCore.Mvc.Versioning` 5.1 (deprecated) | `Asp.Versioning.Mvc` 10 | The old package is unmaintained and predates .NET 10 |
| Image processing | SixLabors.ImageSharp 3.1.12 | SkiaSharp (MIT) | ImageSharp 3.1.12 has open high-severity advisories (GHSA-j3p4-wp97-rph4, GHSA-jjfr-hcj7-qf5w); the fixed 4.1.2+ needs a paid licence key for release builds. AsanRezerve should upgrade too |
| Left out entirely | Payments, ledger, Stripe, SendGrid, Key Vault, unused Autofac reference | Not included | Not needed by this product |

MediatR is pinned to 12.5.0, which stays free under Apache 2.0 but gets no further updates. The code uses only
`IRequest`, `IRequestHandler` and `IPipelineBehavior`, behind the building blocks' `ICommand`/`IQuery`
abstractions. Replacing MediatR with another mediator or a small hand-written dispatcher therefore touches only
the building blocks.

## Risks / Trade-offs

- **[Google's terms for Places data]**
  - Google Maps Platform terms limit caching of Places content.
  - The product owner reviewed this on 2026-10-23, sees no legal obstacle for this use in Iran, and accepted
    the risk.
  - The import source stays pluggable, so OpenStreetMap or Neshan can be added later as another adapter if
    Google access becomes a problem.
- **[Data-entry load of a nationwide catalog]**
  - Bulk approval per city.
  - Optional court details.
  - Deduplication by `place_id`, so re-imports cost nothing.
- **[Cold start: an empty marketplace makes the app useless]**
  - The catalog is nationwide, but acquisition effort starts with a few partner clubs and coaches.
  - Shareable post links bring in the existing Telegram and WhatsApp groups.
  - Search shows recurring availability, not only posts, so a city with few posts still returns people.
  - Hold a closed beta before the store launch.
- **[Harassment, especially of women]**
  - The message-request gate, optional same-gender visibility, one-tap block and report.
  - Gender can be changed only by an admin.
  - OTP-verified phone numbers, and ban evasion blocked through `BannedPhone`.
  - The admin report queue puts high-risk reports first (harassment, underage, several reporters).
- **[Fake or retaliatory ratings]**
  - Only players who actually played can rate.
  - Ratings are double-blind, and averages need 3 ratings.
  - Disputed matches are excluded from both ratings and reliability.
- **[False no-show reports to damage someone's reliability]**
  - A contested no-show becomes Disputed and has no effect.
  - Reliability is shown as a coarse tier.
  - Admins can see repeated disputes.
- **[Stale availability]**
  - 30-day reconfirmation with auto-pause.
  - Players who already have a confirmed match at that time are hidden.
  - Last activity counts in the ranking.
- **[Community context grows too large]**
  - Its modules are kept in separate folders and namespaces.
  - Architecture tests stop the modules from reaching into each other's internals.
  - Ratings/reputation or safety can be extracted later; each communicates through domain events already.
- **[SignalR in Flutter is new ground: AsanRezerve's apps never connected to the hub]**
  - The realtime client sits behind an interface, with a polling fallback.
  - An early spike in the chat slice on real Iranian mobile networks.
- **[Single API instance]**
  - The MVP accepts this.
  - Workers use `SKIP LOCKED`, and the SignalR Redis backplane is a configuration switch.
  - The first scale step is a second instance behind the existing reverse proxy.
- **[Scope: twelve capabilities in one change]**
  - Tasks are cut into vertical slices, each one shippable to staging.
  - The app can go to closed beta after the search and matches slices, before chat and ratings are polished.
- **[Licence drift in libraries (MediatR, AutoMapper, FluentAssertions)]**
  - No AutoMapper.
  - FluentAssertions stays pinned to 7.x as in AsanRezerve, and MediatR to 12.5.0.
  - Both are free, but neither line receives fixes. Their use stays thin, so either can be replaced inside
    the building blocks.

## Migration Plan

Greenfield, so there is no data migration. The rollout runs as vertical slices, each with its tests green and
deployed to staging:

1. **Foundation.** Repository layout, forked building blocks, host, compose, CI, health probes, architecture
   tests.
2. **Identity + Catalog + Profile.** OTP sign-in, onboarding with the 18+ gate, sport profiles, provinces and
   cities seeded, the Google Places import tool, admin review and bulk approval of candidates, manual venue
   entry, block/unblock (so every later slice can test block scenarios); admin panel login and catalog
   management.
3. **Availability + Search.** Publish windows, search players, saved searches without alerts yet.
4. **Matches.** Play posts, join requests, direct invitations, confirmation, cancellation, share links.
5. **Chat.** Message requests, direct and match conversations, realtime hub, FCM for offline delivery.
6. **Attendance + Ratings + Reliability.**
7. **Trust and safety.** Reports, the admin report queue and actions, audit log, ban propagation.
8. **Notifications polish and launch.** Preferences, quiet hours, saved-search digests, reminders. Then a
   closed beta at partner clubs, followed by Cafe Bazaar, Myket and the direct APK.

**Deployment** follows AsanRezerve: GHCR images, `docker compose pull` on the server, a database backup before
each deploy, smoke checks after.

**Rollback:** redeploy the previous image tag. Migrations are additive within a release; a destructive schema
change needs a two-release expand/contract. If a migration fails, restore the pre-deploy backup.

## Open Questions

None of these blocks the specs or the implementation. They must be answered before deployment.

1. **Hosting and domain.** Neither is provisioned yet. Share links and Android App Links read a configurable
   `PublicBaseUrl`, and deployment workflows are written against placeholders until a server exists.
2. **SMS.** A Rallyto-branded OTP template on MeliPayamak needs approval. Should the existing account be
   reused with a new sender line?
Resolved on 2026-10-23:
- the venue list comes from Google and covers all of Iran, and only the Rallyto team enters venues;
- the Google terms risk is accepted by the product owner;
- the admin reviews reports;
- MediatR uses the free 12.5.0 release.
