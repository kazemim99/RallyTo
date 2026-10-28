## ADDED Requirements

### Requirement: Search input and defaults
A player SHALL search with:
- **Sport** (required).
- **Where:** a city (default the profile city) and optional venues in that city (default all venues in the
  city that offer the sport).
- **When:** either one date from today up to 30 days ahead, or a set of weekdays; plus a time window (default
  the whole day).
- **Who:** a level range (default the player's own tier for that sport ± 1) and a partner gender (default
  any).
- **Format** (optional) and **result type:** posts, players, or both (default both).

For a player whose visibility is Same gender only, the partner gender SHALL always be their own gender.

#### Scenario: Defaults applied
- **GIVEN** an intermediate tennis player whose profile city is Tehran
- **WHEN** the player searches tennis with only a date
- **THEN** the search covers all Tehran venues offering tennis, the whole day, levels lower_intermediate to
  advanced, any gender, posts and players

#### Scenario: Restricted player's gender filter
- **GIVEN** a female player with visibility Same gender only
- **WHEN** she searches with partner gender any
- **THEN** only female players and posts open to women are returned

### Requirement: Post results
Post results SHALL be public Open posts that meet all of these:
- the requested sport, at a requested venue;
- start in the future, on the requested date or weekdays;
- time overlapping the requested window;
- at least one open spot;
- a level range that intersects the requested range;
- a partner gender that accepts the searcher;
- if a format was given, the requested format.

Post results SHALL be ordered by start time, soonest first.

#### Scenario: Matching post
- **GIVEN** an Open tennis singles post at Esteghlal on Saturday 1405/08/02, 19:00–20:30, with 1 open spot
- **WHEN** a player searches tennis at Esteghlal for 1405/08/02, 18:00–22:00
- **THEN** the post is returned

#### Scenario: Full post
- **GIVEN** a post whose last spot was filled
- **WHEN** a matching search runs
- **THEN** the post is not returned

### Requirement: Player results from overlapping availability
Player results SHALL be players with an Active availability window that meets all of these:
- the requested sport, at a requested venue;
- matches the requested date or weekdays;
- overlaps the requested time window by at least 60 minutes;
- when a format was given, includes that format.

In addition, the player's level for the sport SHALL be within the requested range and their gender SHALL match
the filter. Each result SHALL show the matching window, the overlapping time, and the shared venues.

#### Scenario: Overlap of two hours
- **GIVEN** player B is available at Esteghlal on Saturdays 18:00–24:00
- **WHEN** player A searches tennis at Esteghlal for Saturday 20:00–22:00
- **THEN** B is returned, with an overlap of 20:00–22:00

#### Scenario: Overlap of thirty minutes
- **GIVEN** player B is available at Esteghlal on Saturdays 18:00–24:00
- **WHEN** player A searches tennis at Esteghlal for Saturday 23:30–24:00
- **THEN** B is not returned

#### Scenario: Level outside the range
- **GIVEN** player B is a beginner
- **WHEN** player A searches the range intermediate–advanced
- **THEN** B is not returned

### Requirement: Search exclusions
Results MUST never include:
- the searcher;
- players or hosts blocked by the searcher, or who blocked the searcher;
- players or hosts hidden from the searcher by same-gender visibility;
- accounts that are not Active, or that have no completed profile;
- paused or expired windows.

For date searches, results MUST also exclude players who already have an Accepted participation in a match
overlapping the requested time on that date.

#### Scenario: Blocked in either direction
- **GIVEN** player B blocked player A
- **WHEN** A searches B's venue and time
- **THEN** neither B nor B's posts are returned

#### Scenario: Already booked at that time
- **GIVEN** player B has a Confirmed match on 1405/08/02 from 19:00 to 20:30
- **WHEN** player A searches B's venue for 1405/08/02, 19:00–21:00
- **THEN** B is not returned as an available player

### Requirement: Ranking of player results
Player results SHALL be ordered by a fit score computed by a deterministic ranking policy. A higher score
comes from:
- a smaller level distance from the searcher;
- a longer overlap;
- a better reliability tier;
- a higher public rating average;
- more recent activity;
- having played together before.

Ties SHALL be broken by most recent activity, then by player id. The weights SHALL be configuration.

#### Scenario: Level closeness ranks first
- **GIVEN** two candidates equal in every factor except level, at distance 0 and 2 from the searcher
- **WHEN** the search runs
- **THEN** the candidate at distance 0 is ranked first

#### Scenario: Reliability affects order
- **GIVEN** two candidates equal in every factor except reliability tier, one High and one Low
- **WHEN** the search runs
- **THEN** the High-reliability candidate is ranked first

### Requirement: Paging
Results SHALL be returned 20 per page, with a continuation token that keeps the same ordering for later pages
of the same query.

#### Scenario: Second page
- **GIVEN** a search with 45 player results
- **WHEN** the client requests the second page with the continuation token
- **THEN** results 21–40 are returned, with no duplicates from page one

### Requirement: Saved searches and alerts
A player SHALL be able to save up to 5 searches with a name, and turn alerts on or off for each.
- A saved search on a specific date SHALL expire after that date.
- When a newly published post or newly published or resumed availability window matches an alert-enabled
  saved search, the owner SHALL be notified. The match is evaluated with all visibility and exclusion rules,
  from the owner's point of view.
- Each saved search MUST produce at most one alert per 6 hours. Matches arriving in the meantime SHALL be
  combined into the next alert with a count.

#### Scenario: New post matches a saved search
- **GIVEN** a saved search for padel in Tehran on Fridays 08:00–12:00 with alerts on
- **WHEN** another player publishes a matching padel post
- **THEN** the owner receives an alert linking to the post

#### Scenario: Alert throttling
- **GIVEN** an alert was sent for a saved search 2 hours ago
- **WHEN** three more matching posts are published
- **THEN** no alert is sent until 6 hours after the previous one, and that alert reports 3 new matches

#### Scenario: Hidden posts do not alert
- **GIVEN** the owner of a saved search is blocked by a host
- **WHEN** that host publishes a matching post
- **THEN** no alert is sent to the owner

### Requirement: Search privacy and rate limits
Search results MUST NOT contain phone numbers, birth dates or exact activity timestamps. A player MUST NOT run
more than 60 searches per minute.

#### Scenario: Excessive searching
- **WHEN** a player sends a 61st search within one minute
- **THEN** the request is rejected as too many requests
