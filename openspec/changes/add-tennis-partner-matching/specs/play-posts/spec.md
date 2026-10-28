## ADDED Requirements

### Requirement: Create a play post
A player SHALL be able to publish a play post (open invitation) with these fields:
- **Game:** a sport they have a sport profile for, a format allowed by the sport, and an Active venue offering
  the sport.
- **Time:** a start time between 30 minutes and 30 days from now, and a duration of 60–240 minutes in
  30-minute steps (default: the sport's session length).
- **Players:** the number of additional players the host already brings (0 up to capacity − 2).
- **Requirements:** a desired level range (minimum and maximum tier; default the host's level ± 1 tier) and a
  partner gender (any, male or female).
- **Court:** whether a court is already booked, and an optional cost-sharing note of up to 200 characters.
- **Description:** optional, up to 500 characters.

Open spots SHALL be capacity − 1 − players brought.

#### Scenario: Tennis singles post
- **WHEN** a player posts tennis singles at Esteghlal Tennis Complex, Tuesday 18:00, 90 minutes, court booked,
  level intermediate to advanced, partner gender any
- **THEN** the post is Open with 1 open spot

#### Scenario: Padel post with a friend
- **WHEN** a player posts padel and brings 1 additional player
- **THEN** the post is Open with 2 open spots out of capacity 4

#### Scenario: Badminton doubles post
- **WHEN** a player posts badminton doubles bringing nobody
- **THEN** the post is Open with 3 open spots

#### Scenario: Squash post
- **WHEN** a player posts squash, which is singles only
- **THEN** the post is Open with 1 open spot out of capacity 2

#### Scenario: Start time too soon
- **WHEN** a player posts a game starting in 10 minutes
- **THEN** the request is rejected

#### Scenario: Padel singles post
- **WHEN** a player posts padel with format singles
- **THEN** the request is rejected

### Requirement: Host visibility constrains the post
When the host's profile visibility is Same gender only, the post's partner gender MUST equal the host's gender.

#### Scenario: Restricted host posts for any gender
- **GIVEN** a female host with visibility Same gender only
- **WHEN** she posts with partner gender any
- **THEN** the post is saved with partner gender female

### Requirement: Who can see a post
A public post SHALL be visible in partner search, on the host's profile and through its share link. It MUST
be hidden from:
- players blocked by the host, or who blocked the host;
- players whose gender the post's partner-gender setting excludes;
- players excluded by the host's same-gender visibility;
- accounts that are not Active;
- everyone, once a host who is not Active can no longer be seen.

#### Scenario: Women-only post hidden from men
- **GIVEN** an Open post with partner gender female
- **WHEN** a male player searches that venue and time
- **THEN** the post is not returned

#### Scenario: Blocked player opens the share link
- **GIVEN** the host blocked player B
- **WHEN** B opens the post's share link while signed in
- **THEN** B sees "this game is not available"

### Requirement: Request to join
A player SHALL be able to request to join an Open post, with an optional message of up to 200 characters. The
request MUST be rejected when any of these holds:
- the requester is the host or already a participant;
- the requester cannot see the post;
- the post has no open spot, or its start time has passed;
- the requester has no sport profile for the sport;
- the requester already has an accepted match overlapping the post's time.

A request from a player whose level is outside the post's range SHALL be allowed and shown to the host as out
of range. The host SHALL be notified of every request.

#### Scenario: In-range request
- **GIVEN** an Open tennis post with range intermediate–advanced
- **WHEN** an intermediate player requests to join with the message «سلام، پایه‌ام»
- **THEN** a pending join request is created and the host is notified

#### Scenario: Out-of-range request
- **GIVEN** an Open post with range intermediate–advanced
- **WHEN** a beginner requests to join
- **THEN** the request is created and the host sees it marked "outside your level range"

#### Scenario: Conflicting match
- **GIVEN** the requester has an accepted match overlapping the post's time
- **WHEN** the requester tries to join
- **THEN** the request is rejected with a schedule-conflict error

### Requirement: Host accepts or declines join requests
The host SHALL be able to accept or decline each pending request before the start time.
- Accepting SHALL make the requester an Accepted participant and reduce the open spots by one.
- When the open spots reach zero, the match SHALL become Confirmed and the remaining pending requests SHALL be
  declined automatically.
- When two accepts compete for the last spot, exactly one SHALL succeed, and the other SHALL fail with "no open
  spot".
- Every requester SHALL be notified of the outcome.

#### Scenario: Last spot filled
- **GIVEN** a singles post with 1 open spot and 3 pending requests
- **WHEN** the host accepts one request
- **THEN** the match is Confirmed, the other two requests are declined, and all three requesters are notified

#### Scenario: Concurrent accept of the last spot
- **GIVEN** a post with 1 open spot and 2 pending requests
- **WHEN** both requests are accepted at the same moment
- **THEN** exactly one participant is Accepted and the other accept fails with "no open spot"

### Requirement: Withdraw a join request
A requester SHALL be able to withdraw a pending request at any time. After acceptance, leaving follows the
match-lifecycle rules.

#### Scenario: Withdraw before decision
- **WHEN** a requester withdraws a pending request
- **THEN** the request is Withdrawn and the host no longer sees it as pending

### Requirement: Editing a post
The host SHALL be able to edit the description, cost note, court-booked flag, level range and partner gender
at any time before the start. Changing the sport, format, venue, start time or duration MUST be allowed only
while no other participant is Accepted. Otherwise the host SHALL cancel the post and create a new one.

#### Scenario: Change time after someone joined
- **GIVEN** a post with one Accepted participant
- **WHEN** the host changes the start time
- **THEN** the change is rejected with a hint to cancel and repost

### Requirement: Post and request limits
A player MUST NOT host more than 5 Open posts at once, and MUST NOT have more than 10 pending join requests at
once.

#### Scenario: Sixth open post
- **GIVEN** a player hosts 5 Open posts
- **WHEN** the player creates another
- **THEN** the request is rejected

### Requirement: Share link
Every public post SHALL have an unguessable share token. The link SHALL be `{PublicBaseUrl}/m/{token}`, where
`PublicBaseUrl` is configuration.
- An anonymous visitor SHALL see a summary and links to install or open the app. The summary contains: sport,
  format, venue and city, Jalali date and time, level range, open spots, court-booked flag, and the host's
  display name and level.
- A signed-in player SHALL land on the post, subject to the visibility rules.
- The host SHALL be able to regenerate the token, which invalidates the old link.
- The summary MUST NOT include the host's photo, age or any contact detail.

#### Scenario: Anonymous visitor
- **WHEN** someone without the app opens a share link from a Telegram group
- **THEN** they see the post summary and the store and APK links, without the host's photo or contact details

#### Scenario: Regenerated link
- **GIVEN** the host regenerated the share token
- **WHEN** someone opens the old link
- **THEN** they see "this link is no longer valid"

### Requirement: Posts stop accepting players at start time
At the start time, an Open post SHALL stop accepting requests, and pending requests SHALL be declined
automatically. The match then follows the match-lifecycle rules: it is confirmed automatically with at least 2
accepted players, and expires otherwise.

#### Scenario: Pending requests at start
- **GIVEN** an Open post with 1 Accepted participant besides the host and 1 pending request
- **WHEN** the start time arrives
- **THEN** the pending request is declined and the match is Confirmed with 2 players
