## ADDED Requirements

### Requirement: Who can rate whom
A player SHALL be able to rate another participant of a Completed match only when all of these hold:
- both are Played in that match;
- the rater is not rating themselves;
- the rating is submitted within 7 days of the match's resolution;
- the rater has not already rated that participant for that match.

Ratings MUST be rejected for Disputed or Unconfirmed matches and for No-show or Contested participants. A
submitted rating MUST NOT be editable.

#### Scenario: Eligible rating
- **GIVEN** a Completed singles match where A and B are Played, resolved 2 days ago
- **WHEN** A rates B
- **THEN** the rating is stored

#### Scenario: Window closed
- **GIVEN** a match resolved 8 days ago
- **WHEN** A tries to rate B
- **THEN** the request is rejected

#### Scenario: Rating a no-show
- **GIVEN** a padel match where D was a No-show
- **WHEN** A tries to rate D
- **THEN** the request is rejected

#### Scenario: Duplicate rating
- **GIVEN** A already rated B for this match
- **WHEN** A submits another rating for B for the same match
- **THEN** the request is rejected

### Requirement: Rating content
A rating SHALL consist of:
- 1 to 5 whole stars;
- up to 3 tags from this fixed list: on time (وقت‌شناس), friendly (خوش‌برخورد), fair line calls (داوری
  منصفانه), good rally (رالی خوب), good sportsmanship (روحیه ورزشی), well organised (هماهنگی خوب);
- a required level-accuracy answer about the ratee's declared level for the match's sport: lower than
  declared, about right, or higher than declared;
- an optional private note of up to 500 characters, visible only to admins.

There SHALL be no public written review.

#### Scenario: Full rating
- **WHEN** A rates B with 4 stars, tags "on time" and "good rally", and level "about right"
- **THEN** the rating is stored with exactly those values

#### Scenario: Missing level answer
- **WHEN** a rating is submitted without a level-accuracy answer
- **THEN** the request is rejected

### Requirement: Double-blind reveal
A rating SHALL stay hidden until the ratee has also rated the rater for the same match, or until the 7-day
window closes, whichever comes first. Hidden ratings MUST NOT affect any displayed aggregate. In doubles, each
pair of participants SHALL be revealed independently.

#### Scenario: Waiting for the other side
- **GIVEN** A rated B and B has not rated A
- **WHEN** anyone views B's profile
- **THEN** B's aggregates do not include A's rating

#### Scenario: Both sides rated
- **GIVEN** A rated B
- **WHEN** B rates A
- **THEN** both ratings are revealed and both players' aggregates are updated

#### Scenario: Window closes with one side
- **GIVEN** A rated B and B never rated A
- **WHEN** the 7-day window closes
- **THEN** A's rating of B is revealed

### Requirement: Public reputation summary per sport
For each sport, a player's profile SHALL show these, computed from revealed ratings in that sport:
- **Stars:** the average to one decimal and the rating count, only from 3 revealed ratings onward. Below that,
  the profile shows "new player".
- **Tags:** the 3 most frequent, only from 3 revealed ratings onward.
- **Level accuracy:** one statement ("most partners say this level is about right / higher / lower"), only
  from 3 revealed ratings onward and when one answer has at least 60% of them.

Individual ratings and their authors MUST NOT be shown to any player.

#### Scenario: Two ratings
- **GIVEN** a player has 2 revealed tennis ratings
- **WHEN** another player views the profile
- **THEN** tennis shows "new player" and no average

#### Scenario: Three ratings
- **GIVEN** a player has revealed tennis ratings of 5, 4 and 4 stars
- **WHEN** another player views the profile
- **THEN** tennis shows 4.3 stars from 3 ratings

#### Scenario: Level feedback majority
- **GIVEN** 5 revealed padel ratings, 4 of them "higher than declared"
- **WHEN** another player views the profile
- **THEN** padel shows "most partners say this level is higher"

#### Scenario: No individual ratings exposed
- **WHEN** a player requests their own received ratings
- **THEN** only the aggregates are returned, without individual stars, tags or rater identities

### Requirement: Reliability tier
Each player SHALL have one reliability tier across all sports, computed from their last 20 resolved
commitments. A commitment is a Played participation, a No-show, or a late cancellation. The score is
`played / (played + no-shows + 0.5 × late cancellations)`, and the tier is:

| Tier | Rule |
|---|---|
| New | fewer than 3 commitments |
| High | score ≥ 0.90 |
| Good | score ≥ 0.75 |
| Low | otherwise |

Disputed and Unconfirmed matches and Contested participations MUST be excluded. The numeric score MUST NOT be
shown to players.

#### Scenario: High reliability
- **GIVEN** a player with 10 Played and 1 No-show
- **WHEN** the tier is computed
- **THEN** the score is 0.909 and the tier is High

#### Scenario: Good reliability at the boundary
- **GIVEN** a player with 6 Played and 2 No-shows
- **WHEN** the tier is computed
- **THEN** the score is 0.75 and the tier is Good

#### Scenario: Late cancellations count half
- **GIVEN** a player with 9 Played and 2 late cancellations
- **WHEN** the tier is computed
- **THEN** the score is 0.90 and the tier is High

#### Scenario: Low reliability
- **GIVEN** a player with 3 Played and 2 No-shows
- **WHEN** the tier is computed
- **THEN** the score is 0.60 and the tier is Low

#### Scenario: New player
- **GIVEN** a player with 2 Played
- **WHEN** the tier is computed
- **THEN** the tier is New

### Requirement: Rating prompts
When a match is resolved as Completed, every Played participant SHALL be asked to rate the other Played
participants. A participant who has not rated by day 5 SHALL get one reminder.

#### Scenario: Reminder on day five
- **GIVEN** A has not rated B, 5 days after the match was resolved
- **WHEN** the reminder check runs
- **THEN** A receives one rating reminder

### Requirement: Admin oversight of ratings
Admins SHALL be able to see individual ratings, their authors and private notes, and to remove a rating as
abusive, with a reason. Removing a rating SHALL recompute the affected aggregates.

#### Scenario: Remove an abusive rating
- **WHEN** an admin removes a 1-star rating with the reason "retaliation after a dispute"
- **THEN** the rating no longer counts in the ratee's aggregates and the removal is audited
