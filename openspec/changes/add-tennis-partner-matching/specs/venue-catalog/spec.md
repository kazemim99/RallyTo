## ADDED Requirements

### Requirement: Provinces and cities of Iran
The system SHALL ship with all 31 provinces of Iran and their cities, with Persian names. Lists SHALL be
ordered by Persian collation. Within a province, cities with at least one active venue SHALL be listed first.

#### Scenario: List cities of a province
- **WHEN** a client requests the cities of Isfahan province
- **THEN** it receives the province's cities in Persian, with venue-bearing cities first

### Requirement: Venue record
A venue SHALL have:
- a Persian name;
- a city;
- a free-text address;
- an optional public phone number;
- optional coordinates of the club itself;
- a status: Active or Hidden;
- an optional source reference (a Google `place_id`);
- one or more offered sports.

Each offered sport SHALL record:
- court count (optional);
- setting: indoor, outdoor or both;
- surface (optional, from a per-sport list);
- whether lighting is available for evening play.

#### Scenario: Venue details
- **WHEN** a player opens Esteghlal Tennis Complex
- **THEN** the player sees name, city, address, the offered sports with court information, and the map
  location when coordinates exist

### Requirement: Import candidate venues from Google Places
An admin-run import tool SHALL query Google Places for each city and sport keyword, and submit the results to
the system as venue candidates. Candidates SHALL NOT be visible to players. The import SHALL be idempotent:
- A result whose `place_id` belongs to an existing venue SHALL be marked "already in catalog".
- A result already present as a pending or rejected candidate SHALL be skipped.

The import endpoint SHALL be admin-only.

#### Scenario: Keywords cover every seeded sport
- **WHEN** the tool runs for a city
- **THEN** it searches the keywords for tennis, padel, badminton and squash (for example «باشگاه تنیس»,
  «پدل», «سالن بدمینتون», «اسکواش»)

#### Scenario: First import for a city
- **WHEN** the tool imports 12 results for "باشگاه تنیس" in Shiraz
- **THEN** 12 pending candidates exist for Shiraz, and players see no new venues

#### Scenario: Re-running the import
- **GIVEN** a previous import created candidates, and one of them was rejected
- **WHEN** the same import runs again
- **THEN** no duplicate candidates are created and the rejected place does not reappear

#### Scenario: Place already in the catalog
- **GIVEN** an active venue has `place_id` P
- **WHEN** an import result with `place_id` P arrives
- **THEN** no candidate is created for it

### Requirement: Admin review of candidates
An admin SHALL review each pending candidate and choose one of:
- **Approve.** The admin sets or edits the name, address, coordinates and offered sports, and an Active venue
  is created with the candidate's `place_id`.
- **Merge** into an existing venue. That venue gains the `place_id`.
- **Reject**, with a reason.

Every decision SHALL be recorded with the admin and time. Because the import covers the whole country, an admin
SHALL also be able to approve several candidates of one city at once, assigning them the same sports. Court
details stay optional and can be filled in later.

#### Scenario: Bulk approval
- **GIVEN** 15 pending tennis candidates in Mashhad
- **WHEN** an admin selects 12 of them and approves them with sport tennis
- **THEN** 12 Active tennis venues are created in Mashhad, and the other 3 stay pending

#### Scenario: Approve a candidate
- **WHEN** an admin approves a candidate and selects tennis with 6 outdoor courts with lighting
- **THEN** an Active venue offering tennis is created and appears in player venue lists

#### Scenario: Merge a duplicate
- **WHEN** an admin merges a candidate into the existing venue «مجموعه ورزشی انقلاب»
- **THEN** no new venue is created and the existing venue records the candidate's `place_id`

### Requirement: Only the Rallyto team enters venues
Venues SHALL be created and edited only by admins, through candidate review or manual entry. Players and clubs
MUST NOT be able to create or edit venues, and clubs SHALL have no accounts or management features. An admin
SHALL be able to add a venue manually with the same fields as an approved candidate. When an active venue with
a similar name exists in the same city, the admin SHALL be shown it before saving.

#### Scenario: Admin adds a club that Google does not list
- **WHEN** an admin manually adds «باشگاه تنیس آفتاب» in Karaj, offering tennis with 4 outdoor courts
- **THEN** an Active venue is created without a source reference and appears in player venue lists

#### Scenario: Similar name already exists
- **GIVEN** an active venue «باشگاه تنیس آفتاب» exists in Karaj
- **WHEN** an admin starts adding «باشگاه آفتاب» in Karaj
- **THEN** the admin is shown the existing venue before saving

#### Scenario: Player tries to create a venue
- **WHEN** an account without the Admin role calls a venue-creation endpoint
- **THEN** the request is rejected as forbidden

### Requirement: Venue listing and search
Players SHALL be able to list Active venues by city and sport, and search them by name. Name search MUST treat
these as equivalent:
- Arabic and Persian yeh and kaf (ي/ی, ك/ک);
- the zero-width non-joiner;
- spacing.

Hidden venues and candidates MUST NOT appear.

#### Scenario: Arabic yeh in the query
- **WHEN** a player searches «باشگاه تنيس» (with Arabic yeh) in Tehran
- **THEN** venues named «باشگاه تنیس …» are returned

#### Scenario: Filter by sport
- **WHEN** a player lists venues in Tehran for padel
- **THEN** only active venues offering padel are returned

### Requirement: A venue must offer the sport
Availability windows, play posts and invitations MUST reference only Active venues that offer the chosen sport.

#### Scenario: Sport not offered
- **GIVEN** a venue offers only tennis
- **WHEN** a player creates a badminton post at that venue
- **THEN** the request is rejected

### Requirement: Hiding a venue
An admin SHALL be able to hide a venue, for example a closed club. A hidden venue:
- SHALL disappear from listings and from new availability and posts;
- SHALL be removed from availability windows that reference it, and a window left with no venue SHALL be
  paused;
- SHALL leave existing future matches in place, and their participants SHALL be notified.

#### Scenario: Hide a club
- **GIVEN** a venue with two availability windows and one future match
- **WHEN** an admin hides the venue
- **THEN** the venue is removed from both windows, a window with no other venue is paused, and the match's
  participants are notified

### Requirement: Map shows clubs, never players
When a venue has coordinates, clients SHALL show its location on a map. The system MUST NOT request, store or
display any player's location.

#### Scenario: Venue without coordinates
- **WHEN** a player opens a venue without coordinates
- **THEN** the address is shown, without a map
