## ADDED Requirements

### Requirement: Block a player
A player SHALL be able to block another player from a profile, a search result, a post, a match, a
conversation or a message request, and SHALL be able to unblock them later. While either player blocks the
other, neither SHALL be able to:
- see the other's profile, availability or posts;
- find the other in search;
- invite the other, or request to join the other's posts;
- open or continue a direct conversation with the other.

The blocked player MUST NOT be told about the block.

#### Scenario: Block from a message request
- **WHEN** B blocks A from A's message request
- **THEN** the request disappears, and A can no longer find, invite or message B

#### Scenario: Unblock
- **GIVEN** A blocked B
- **WHEN** A unblocks B
- **THEN** both can find each other again, and earlier conversations become usable again

#### Scenario: Block stays silent
- **GIVEN** A blocked B
- **WHEN** B opens A's profile
- **THEN** B receives the same "not found" response as for a non-existent profile

### Requirement: Report content and behaviour
A player SHALL be able to report a player, a message, a play post or a profile photo. A report carries:
- a reason: harassment, inappropriate content, fake profile, spam or advertising, unsafe behaviour or
  repeated no-shows, underage user, or other;
- optional details of up to 1000 characters.

The system SHALL store an evidence snapshot of the target as it was at report time: the message text, the post
text, the profile fields, or a copy of the photo. A reporter MUST NOT have more than one open report on the
same target. The reporter SHALL be offered to block the target in the same step. The reporter SHALL be able to
see whether a report is open or resolved, but not the action taken.

#### Scenario: Report a harassing message
- **WHEN** B reports A's message with reason harassment and blocks A in the same step
- **THEN** an open report with a snapshot of the message exists, and A is blocked

#### Scenario: Duplicate open report
- **GIVEN** B has an open report on A's profile
- **WHEN** B reports A's profile again
- **THEN** the request is rejected with "you already reported this"

### Requirement: Admin report queue
Admins SHALL work through reports in the admin panel. The queue SHALL be grouped by target and ordered by
priority, then by age. A report SHALL be high priority when either holds:
- its reason is harassment or underage user;
- its target has open reports from 3 or more distinct reporters within 7 days.

For each target, the admin SHALL see:
- the evidence snapshots;
- earlier reports and actions;
- the player's reliability, their disputed matches, and the private notes left in ratings about them.

The system MUST NOT suspend or ban anyone automatically.

#### Scenario: Several reporters raise priority
- **GIVEN** three different players report the same player within 7 days
- **WHEN** an admin opens the queue
- **THEN** that player's reports are grouped and shown as high priority

#### Scenario: No automatic suspension
- **GIVEN** a player has 5 open reports
- **WHEN** no admin has acted
- **THEN** the player's account is still Active

### Requirement: Admin actions
An admin SHALL be able to resolve a report by dismissing it or by taking one or more actions:
- warn the player, who receives the warning text;
- remove the profile photo;
- hide a post, which removes it from search and share links while existing participants keep the match;
- delete a message for everyone;
- suspend the account until a date;
- lift a suspension;
- ban the account permanently;
- correct the player's gender.

Every action SHALL record the admin, time, reason and related report. The affected player SHALL be informed of
warnings, suspensions (with end date and reason) and bans. Suspensions and bans SHALL take effect through the
identity capability.

#### Scenario: Suspend for a week
- **WHEN** an admin suspends a player until 1405/08/08 with the reason "harassment in chat"
- **THEN** the account is Suspended, the player is informed of the reason and end date, the player leaves all
  future matches, and the profile disappears from search

#### Scenario: Ban
- **WHEN** an admin bans a player
- **THEN** the account is Banned, the phone hash is recorded, and the same number cannot register again

#### Scenario: Hide a post
- **GIVEN** an Open post with one accepted participant
- **WHEN** an admin hides the post for advertising
- **THEN** the post leaves search and its share link stops working, and the accepted participant's match
  remains

### Requirement: Admin audit log
Every admin action across the system SHALL be listed in an audit log with filters for admin, target player,
action type and date. Covered actions include moderation, role changes, catalog edits, venue review, rating
removal and gender changes.

#### Scenario: Review an admin's actions
- **WHEN** an admin filters the audit log by another admin and the last 7 days
- **THEN** every action that admin took in that period is listed with its reason

### Requirement: Disputed matches are visible to admins
Admins SHALL see disputed matches and contested no-shows, and a per-player count of disputes in the last 90
days, so they can spot players who repeatedly abuse attendance confirmation.

#### Scenario: Repeated disputes
- **GIVEN** a player was involved in 4 disputed matches in the last 90 days
- **WHEN** an admin opens that player in the report queue
- **THEN** the dispute count of 4 is shown with links to the matches
