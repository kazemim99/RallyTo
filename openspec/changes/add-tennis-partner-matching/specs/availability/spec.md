## ADDED Requirements

### Requirement: Publish a recurring weekly window
A player SHALL be able to publish a recurring availability window with:
- one sport the player has a sport profile for;
- 1–3 Active venues in the same city, each offering that sport;
- one or more weekdays (the Iranian week, Saturday first);
- a start and end time in Tehran local time;
- formats, a subset of the sport's formats;
- an optional end date;
- an optional note of up to 200 characters.

Times SHALL use 30-minute steps. A window SHALL last at least 60 minutes. A window SHALL end at or before
24:00 and MUST NOT cross midnight.

#### Scenario: Evening tennis window
- **WHEN** a player publishes tennis availability at Esteghlal Tennis Complex, Tehran, on Saturday and Monday
  from 18:00 to 24:00, format singles or doubles
- **THEN** the window is Active and can be found by searches overlapping those days and times

#### Scenario: Too short
- **WHEN** a player publishes a window from 18:00 to 18:30
- **THEN** the request is rejected because windows last at least 60 minutes

#### Scenario: Crossing midnight
- **WHEN** a player publishes a window from 22:00 to 02:00
- **THEN** the request is rejected, and the error suggests splitting it into two windows

#### Scenario: Venues in different cities
- **WHEN** a player selects one venue in Tehran and one in Karaj for the same window
- **THEN** the request is rejected

#### Scenario: Padel window with singles
- **WHEN** a player publishes padel availability with format singles
- **THEN** the request is rejected because padel is doubles only

### Requirement: Publish a one-off window
A player SHALL be able to publish availability for one specific date, entered on the Jalali calendar. The
date SHALL be from today up to 60 days ahead, and the same time, venue and format rules as recurring windows
apply. A one-off window whose end time has passed MUST NOT be accepted.

#### Scenario: Specific Friday morning
- **WHEN** a player publishes padel availability for Friday 1405/08/08, 08:00–11:00, at two Tehran venues
- **THEN** the window is Active for that date only

#### Scenario: Too far ahead
- **WHEN** a player publishes a one-off window 75 days ahead
- **THEN** the request is rejected

### Requirement: Window limits and duplicates
A player MUST NOT have more than 10 Active windows. A new window MUST be rejected when an existing Active
window of the same player matches all of these:
- same sport;
- at least one shared venue;
- at least one shared day (a weekday, or the specific date);
- overlapping time.

The rejection SHALL point to the existing window to edit.

#### Scenario: Eleventh window
- **GIVEN** a player has 10 Active windows
- **WHEN** the player publishes another
- **THEN** the request is rejected

#### Scenario: Overlapping duplicate
- **GIVEN** a tennis window at Esteghlal on Saturdays 18:00–24:00
- **WHEN** the player publishes tennis at Esteghlal on Saturdays 20:00–22:00
- **THEN** the request is rejected, with a reference to the existing window

### Requirement: Edit, pause, resume and delete
A player SHALL be able to edit, pause, resume and delete their own windows. Paused windows MUST NOT appear in
search or on the profile. Edits SHALL be validated with the same rules as creation.

#### Scenario: Pause during travel
- **WHEN** a player pauses a window
- **THEN** it disappears from search results until resumed

### Requirement: Recurring windows must be reconfirmed
A recurring window SHALL stay Active only while confirmed within the last 30 days. Creating, editing, resuming
or tapping "still available" confirms it. On day 27 without confirmation, the player SHALL be asked whether
they are still available. On day 30 without confirmation, the window SHALL be paused automatically.

#### Scenario: Reminder before auto-pause
- **GIVEN** a recurring window last confirmed 27 days ago
- **WHEN** the daily staleness check runs
- **THEN** the player receives a "still available?" notification

#### Scenario: Auto-pause
- **GIVEN** a recurring window last confirmed 30 days ago
- **WHEN** the daily staleness check runs
- **THEN** the window is paused and the player is notified

#### Scenario: Confirmation resets the clock
- **GIVEN** a reminder was sent on day 27
- **WHEN** the player taps "still available"
- **THEN** the window stays Active for another 30 days

### Requirement: Expiry
A one-off window SHALL expire when its end time passes. A recurring window with an end date SHALL expire after
that date. Expired windows MUST NOT appear in search and SHALL remain in the player's own list for 30 days.

#### Scenario: One-off window expires
- **GIVEN** a one-off window for yesterday 18:00–20:00
- **WHEN** a search runs today
- **THEN** that window is not considered

### Requirement: Windows follow account, profile and venue state
Windows MUST NOT appear in search in any of these cases:
- the owner's account is not Active;
- the owner removed the sport profile for that sport;
- every venue of the window is hidden.

Windows of a deleted account SHALL be removed.

#### Scenario: Suspended player
- **GIVEN** a player with Active windows is suspended
- **WHEN** another player searches the same venue and time
- **THEN** the suspended player is not returned

### Requirement: Who can see a player's windows
A player's Active windows SHALL be visible only through partner search and the player's profile, and only to
viewers who can see that profile under the blocking and same-gender visibility rules. The display SHALL show,
for each window: sport, venues, days or date, time range in Persian digits, and formats.

#### Scenario: Blocked viewer
- **GIVEN** player A blocked player B
- **WHEN** B searches the venue and time of A's window
- **THEN** A's window is not returned

### Requirement: Times are Tehran wall-clock times
Recurring windows SHALL be interpreted in Asia/Tehran. A weekday window SHALL match a date when that date falls
on the same weekday in Tehran and is within the window's validity.

#### Scenario: Saturday window matches a Saturday date
- **GIVEN** a window on Saturdays 18:00–24:00
- **WHEN** a search asks for 1405/08/02, a Saturday, 19:00–21:00
- **THEN** the window matches
