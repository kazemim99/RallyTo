## ADDED Requirements

### Requirement: Seeded sports
The system SHALL ship with four active sports, each with a stable code and Persian and English names:
tennis (`tennis`, تنیس), padel (`padel`, پدل), badminton (`badminton`, بدمینتون) and squash (`squash`,
اسکواش).

#### Scenario: List sports
- **WHEN** a client requests the sport list
- **THEN** it receives tennis, padel, badminton and squash with their Persian names, in the admin-defined order

### Requirement: Play formats per sport
Each sport SHALL define its allowed play formats and players per side. A match's capacity is 2 × players per
side.

| Sport | Allowed formats | Capacity |
|---|---|---|
| Tennis | singles (1 per side), doubles (2 per side) | 2 or 4 |
| Badminton | singles (1 per side), doubles (2 per side) | 2 or 4 |
| Padel | doubles (2 per side) only | 4 |
| Squash | singles (1 per side) only | 2 |

Every capability that takes a format MUST reject a format the sport does not allow.

#### Scenario: Padel is doubles only
- **WHEN** a client reads the padel formats
- **THEN** the only format is doubles, with capacity 4

#### Scenario: Squash is singles only
- **WHEN** a client reads the squash formats
- **THEN** the only format is singles, with capacity 2

#### Scenario: Unsupported format is rejected
- **WHEN** any request combines padel with singles
- **THEN** the request is rejected with a validation error naming the allowed formats

### Requirement: Five-tier self-declared level scale
All sports SHALL share five ordered level tiers: `beginner` (مبتدی), `lower_intermediate` (متوسط رو به پایین),
`intermediate` (متوسط), `advanced` (پیشرفته), `professional` (حرفه‌ای). Each sport SHALL carry its own
player-facing Persian description for each tier, describing what a player at that tier can typically do in that
sport. The tier order SHALL be used for level ranges and level distance.

#### Scenario: Tier descriptions differ by sport
- **WHEN** a client requests the level scale for badminton
- **THEN** it receives the five tiers in order, each with the badminton-specific description

#### Scenario: Level distance
- **WHEN** the system compares `beginner` and `intermediate`
- **THEN** the distance is 2 tiers

### Requirement: Default session length
Each sport SHALL have a default session length, used as the default duration of new play posts and
invitations: tennis 90 minutes, padel 90 minutes, badminton 60 minutes, squash 60 minutes.

#### Scenario: Default duration for badminton
- **WHEN** a player starts creating a badminton post without choosing a duration
- **THEN** the duration is 60 minutes

### Requirement: Admin manages the sport catalog
Admins SHALL be able to:
- add a sport, with its formats, level descriptions and default session length;
- edit names, descriptions and order;
- deactivate a sport.

Deactivating a sport SHALL hide it from new profiles, availability, posts and searches, and SHALL keep existing
data readable. An admin MUST NOT be able to remove a format while future matches use it.

#### Scenario: Add a sport
- **WHEN** an admin adds table tennis with singles and doubles formats and five tier descriptions
- **THEN** players can add table tennis to their profiles

#### Scenario: Deactivate a sport
- **GIVEN** badminton is deactivated
- **WHEN** a player tries to publish badminton availability
- **THEN** the request is rejected
- **AND** past badminton matches remain visible in match history

#### Scenario: Remove a format in use
- **GIVEN** a future tennis doubles match exists
- **WHEN** an admin tries to remove doubles from tennis
- **THEN** the change is rejected

### Requirement: Catalog is readable without sign-in
Sports, formats and level descriptions SHALL be readable anonymously, because the onboarding screens and
shared post pages need them.

#### Scenario: Anonymous read
- **WHEN** an unauthenticated client requests the sport list
- **THEN** the list is returned
