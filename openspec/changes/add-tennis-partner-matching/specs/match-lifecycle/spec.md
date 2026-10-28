## ADDED Requirements

### Requirement: Direct invitation
A player SHALL be able to invite players found through search or on a profile to a concrete game. The game
has a sport, format, venue, start time, duration and the number of players the host brings, with the same
rules as play posts: a future start within 30 days, a venue offering the sport, a format allowed by the sport.
- The number of invitees MUST NOT exceed capacity − 1 − players brought.
- Every invitee MUST be visible to the inviter under the blocking and same-gender visibility rules, and MUST
  have a sport profile for the sport.
- The invitation creates a private match in state Pending, with each invitee in state Invited and notified. An
  optional message of up to 200 characters may be included.

#### Scenario: Invite a player for singles
- **WHEN** player A invites player B to tennis singles at Esteghlal on Saturday 1405/08/02 at 19:00
- **THEN** a private Pending match exists with A as host and B as Invited, and B is notified

#### Scenario: Too many invitees
- **WHEN** a host invites 4 players to a padel game while bringing nobody
- **THEN** the request is rejected because capacity allows at most 3 invitees

#### Scenario: Inviting a blocked player
- **GIVEN** player B blocked player A
- **WHEN** A tries to invite B
- **THEN** the request is rejected as "player not found"

### Requirement: Responding to an invitation
An invitee SHALL be able to accept or decline until the start time.
- Accepting MUST be rejected when the invitee already has an Accepted participation in an overlapping match.
- When accepted participants fill the capacity, together with the players brought, the match SHALL become
  Confirmed.
- When every invitee of a private match has declined, the match SHALL become Cancelled.
- An invitation not answered by the start time SHALL become Expired.
- The host SHALL be notified of every response.

#### Scenario: Invitee accepts singles
- **GIVEN** a private singles match with B Invited
- **WHEN** B accepts
- **THEN** B is Accepted, the match is Confirmed, and the host is notified

#### Scenario: All invitees decline
- **GIVEN** a private match with two invitees
- **WHEN** both decline
- **THEN** the match is Cancelled and the host is notified

#### Scenario: Schedule conflict
- **GIVEN** B is Accepted in another match overlapping the invitation's time
- **WHEN** B accepts the invitation
- **THEN** the accept is rejected with a schedule-conflict error

### Requirement: Hosts can invite players into their own post
The host of an Open post SHALL be able to invite players directly into remaining open spots. An invitation
SHALL hold a spot only once accepted.

#### Scenario: Fill a padel post by invitation
- **GIVEN** an Open padel post with 2 open spots
- **WHEN** the host invites a player who accepts
- **THEN** the post has 1 open spot left

### Requirement: Match states
A match SHALL be in exactly one of these states: Open (public, accepting requests), Pending (private, awaiting
invitees), Confirmed, Completed, Disputed, Unconfirmed, Cancelled, Expired. The transitions are:
- **Open/Pending → Confirmed:** when the capacity is filled, or when the host confirms early with at least 2
  accepted players including the host.
- **At the start time:** an Open or Pending match with at least 2 accepted players becomes Confirmed. One with
  fewer becomes Expired, and its participants are notified.
- **Open, Pending or Confirmed → Cancelled:** when the host cancels before the start, with an optional reason.
  All participants are notified.
- **Confirmed → Completed, Disputed or Unconfirmed:** by attendance resolution.

Concurrent changes to one match MUST NOT exceed its capacity or lose an update.

#### Scenario: Host confirms early for a doubles game
- **GIVEN** a tennis doubles post with the host and 2 accepted players
- **WHEN** the host confirms early
- **THEN** the match is Confirmed with 3 players and stops accepting requests

#### Scenario: Expired for lack of players
- **GIVEN** an Open singles post with no accepted player besides the host
- **WHEN** the start time arrives
- **THEN** the match is Expired and the host is notified

### Requirement: Leaving and removal
An accepted participant SHALL be able to leave before the start time. The host SHALL be able to remove an
accepted participant before the start time. A spot freed this way in a public match SHALL reopen, and a
Confirmed public match SHALL return to Open while its start time is in the future. The host and the remaining
participants SHALL be notified.

#### Scenario: Participant leaves a full public match
- **GIVEN** a Confirmed public singles match that starts in 2 days
- **WHEN** the non-host participant leaves
- **THEN** the match is Open again with 1 open spot and the host is notified

### Requirement: Late cancellations are recorded
A late cancellation SHALL be recorded for the acting player in these cases:
- an accepted participant leaves a Confirmed match less than 12 hours before its start;
- the host cancels a Confirmed match less than 12 hours before its start.

No late cancellation SHALL be recorded:
- for leaving or cancelling a match that was not Confirmed;
- for leaving a match because of a block between participants;
- for players removed because their account was suspended, banned or deleted.

#### Scenario: Leaving five hours before
- **GIVEN** a Confirmed match starting in 5 hours
- **WHEN** a participant leaves
- **THEN** a late cancellation is recorded for that participant

#### Scenario: Leaving two days before
- **GIVEN** a Confirmed match starting in 2 days
- **WHEN** a participant leaves
- **THEN** no late cancellation is recorded

#### Scenario: Leaving after blocking a participant
- **GIVEN** a Confirmed match starting in 5 hours, and participant A blocked participant B
- **WHEN** A leaves the match
- **THEN** no late cancellation is recorded for A

### Requirement: No double-booking
A player MUST NOT hold two Accepted participations in matches whose times overlap.

#### Scenario: Accepting a second overlapping game
- **GIVEN** a player is Accepted in a match from 18:00 to 19:30
- **WHEN** a host tries to accept the player's join request for another match at 19:00 the same day
- **THEN** the accept fails with a schedule-conflict error

### Requirement: Match details are for participants
The participant list and every participant's state SHALL be visible only to the host and the players
involved in the match (Invited, Requested or Accepted). Everyone else SHALL see at most the public post
summary.

#### Scenario: Non-participant views a match
- **WHEN** a player who is not involved opens a Confirmed private match by id
- **THEN** the response is "not found"

### Requirement: Attendance confirmation
When a Confirmed match ends, every accepted participant SHALL be asked whether the game was played. The answer
window SHALL be 72 hours from the end time. Each participant SHALL answer "played" or "did not happen", and may
flag other participants as no-shows. Resolution SHALL happen when every participant has answered or when the
window closes, whichever is first:
- **Match outcome:**
  - **Completed:** at least one "played" and no "did not happen".
  - **Disputed:** both "played" and "did not happen" were answered.
  - **Unconfirmed:** no answers, or only "did not happen".
- **Per participant, in a Completed match:**
  - **Played:** the participant answered "played", or did not answer and was not flagged.
  - **No-show:** flagged by at least one other participant without answering "played".
  - **Contested:** flagged, but answered "played".
- Disputed and Unconfirmed matches, and Contested participants, MUST have no effect on ratings or reliability.

#### Scenario: Singles, both say played
- **WHEN** both singles players answer "played"
- **THEN** the match is Completed and both are Played, without waiting for the window to close

#### Scenario: Singles, one silent
- **GIVEN** the host answered "played" and the partner did not answer
- **WHEN** the 72-hour window closes
- **THEN** the match is Completed and both are Played

#### Scenario: Played against did not happen
- **WHEN** one participant answers "played" and the other answers "did not happen"
- **THEN** the match is Disputed, and neither player can rate or is affected in reliability

#### Scenario: Doubles with a no-show
- **GIVEN** a padel match where three players answer "played" and flag the fourth as a no-show
- **WHEN** the fourth does not answer within 72 hours
- **THEN** the match is Completed, the three are Played and the fourth is a no-show

#### Scenario: Contested no-show
- **GIVEN** a padel match where three players flag the fourth as a no-show
- **WHEN** the fourth answers "played"
- **THEN** the match is Completed, the fourth is Contested, and the three others are Played

#### Scenario: Nobody answers
- **WHEN** the window closes without any answer
- **THEN** the match is Unconfirmed

### Requirement: Match history
A player SHALL see their upcoming and past matches with sport, venue, Jalali date and time, participants and
outcome. Each participant SHALL be shown as anonymised when their account was deleted.

#### Scenario: Past matches list
- **WHEN** a player opens match history
- **THEN** past matches are listed newest first, with their outcome

### Requirement: Account changes affect future matches
When a participant's account becomes Suspended, Banned or Deleted, the system SHALL apply these rules:
- the participant SHALL be removed from all future matches;
- a match hosted by that participant SHALL be Cancelled;
- the remaining participants SHALL be notified, without being told the reason.

#### Scenario: Host is banned
- **GIVEN** a Confirmed match hosted by player H
- **WHEN** H is banned
- **THEN** the match is Cancelled and the other participants are notified that the game was cancelled

### Requirement: Blocks between participants of a future match
A block between two participants of a future match SHALL NOT cancel the match. The blocker SHALL be able to
leave without a late cancellation. A host who blocks a participant SHALL be able to remove them.

#### Scenario: Host blocks a participant
- **GIVEN** a Confirmed match where the host blocks participant B
- **WHEN** the host removes B
- **THEN** B is Removed and notified that they were removed from the game, without mention of a block
