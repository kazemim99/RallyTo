## ADDED Requirements

### Requirement: Profile is required before using the product
An account without a completed profile SHALL be limited to these actions:
- onboarding;
- reading the catalog;
- signing out;
- deleting the account.

Every other player endpoint MUST respond with a "profile required" error until the profile exists.

#### Scenario: Search before onboarding
- **GIVEN** a signed-in account without a profile
- **WHEN** it calls partner search
- **THEN** the request is rejected with "profile required"

### Requirement: Create a profile
A player SHALL create a profile with these fields:
- a display name of 2–30 characters (letters, digits, spaces and the Persian zero-width non-joiner only);
- gender (male or female);
- birth date, entered on the Jalali calendar;
- city, from the venue catalog;
- at least one sport profile.

A profile photo and a bio of up to 300 characters are optional.

#### Scenario: Successful onboarding
- **WHEN** a player submits display name «علی», gender male, birth date 1375/05/10, city Tehran, and a tennis
  sport profile
- **THEN** the profile is created and the account counts as profile-completed

#### Scenario: Missing sport profile
- **WHEN** a player submits a profile with no sport profile
- **THEN** the request is rejected with a validation error

### Requirement: Players must be 18 or older
The system MUST reject profile creation when the birth date makes the player younger than 18 years on the
current date in Asia/Tehran. A rejected birth date MUST NOT be stored.

#### Scenario: Seventeen-year-old is rejected
- **GIVEN** today is 1405/08/01 in Tehran
- **WHEN** a player enters birth date 1387/08/02
- **THEN** profile creation is rejected with "you must be 18 or older"
- **AND** no birth date is stored

#### Scenario: Eighteenth birthday today
- **GIVEN** today is 1405/08/01 in Tehran
- **WHEN** a player enters birth date 1387/08/01
- **THEN** the profile is created

### Requirement: Sport profiles
For each sport they play, a player SHALL keep one sport profile with:
- a self-declared level tier from the sport's five-tier scale;
- a playing-experience band: under 6 months, 6–12 months, 1–3 years, 3–5 years, or over 5 years;
- preferred formats, a non-empty subset of the sport's allowed formats;
- goals, at least one of: rally/practice, friendly match, competitive set, fitness.

Players SHALL be able to add, edit and remove sport profiles at any time, subject to these limits:
- The last remaining sport profile MUST NOT be removable.
- A sport profile MUST NOT be removable while the player has a future match in that sport.
- Removing a sport profile SHALL deactivate the player's availability in that sport.

#### Scenario: Add padel with doubles
- **WHEN** a player adds a padel sport profile with level intermediate, experience 1–3 years, format doubles
  and goal friendly match
- **THEN** the padel sport profile is saved

#### Scenario: Padel singles preference rejected
- **WHEN** a player sets singles as a preferred padel format
- **THEN** the request is rejected

#### Scenario: Remove a sport with a future match
- **GIVEN** a player has a confirmed tennis match tomorrow
- **WHEN** the player removes their tennis sport profile
- **THEN** the request is rejected and the match is unchanged

#### Scenario: Removing a sport deactivates its availability
- **GIVEN** a player has active badminton availability and no future badminton matches
- **WHEN** the player removes the badminton sport profile
- **THEN** the badminton availability windows stop appearing in search

### Requirement: Home clubs
A player SHALL be able to mark up to 5 active venues as home clubs. Home clubs are suggested by default when
the player creates availability or posts.

#### Scenario: Sixth home club
- **GIVEN** a player already has 5 home clubs
- **WHEN** the player adds another
- **THEN** the request is rejected

### Requirement: Gender is fixed after onboarding
A player MUST NOT be able to change their own gender after onboarding. An admin SHALL be able to change it with
a recorded reason. The change SHALL be audited and the player SHALL be notified.

#### Scenario: Player tries to change gender
- **WHEN** a player submits a profile update with a different gender
- **THEN** the gender is not changed and the request is rejected

#### Scenario: Admin corrects gender
- **WHEN** an admin changes a player's gender with the reason "chosen by mistake at sign-up"
- **THEN** the gender is updated, an audit record is written and the player is notified

### Requirement: Age is shown only as a range
Other players SHALL see a player's age as one of these ranges: 18–24, 25–34, 35–44, 45–54, 55+. The birth date
MUST NOT be returned to anyone except the owner and admins.

#### Scenario: Age range on a profile
- **GIVEN** a player born 1370/01/01 and today 1405/08/01
- **WHEN** another player views the profile
- **THEN** the age shown is 35–44 and no birth date is present

### Requirement: Same-gender visibility setting
A player SHALL be able to set profile visibility to Everyone (the default) or Same gender only. While Same
gender only is set, the player:
- MUST appear only to players of the same gender, in profiles, search results, play posts, invitations and
  chat;
- SHALL see and interact only with players of the same gender, so that no interaction reveals the player to
  others;
- SHALL have posts restricted to partner gender equal to the player's own gender.

#### Scenario: Hidden from the opposite gender
- **GIVEN** a female player with visibility Same gender only
- **WHEN** a male player opens her profile or searches her club and time
- **THEN** her profile is not found and she is absent from the results

#### Scenario: Visible to the same gender
- **GIVEN** a female player with visibility Same gender only
- **WHEN** another female player searches her club and time
- **THEN** she appears in the results

#### Scenario: Restricted player cannot contact the opposite gender
- **GIVEN** a female player with visibility Same gender only
- **WHEN** she tries to invite or message a male player
- **THEN** the request is rejected

### Requirement: Viewing another player's profile
A player SHALL be able to view another player's profile. The view contains:
- display name, photo, gender, age range, city, bio;
- sport profiles (level with the sport's tier description, experience, formats, goals);
- home clubs and active availability;
- the public reputation summary and reliability tier from player ratings;
- member-since month and a coarse last-active indicator: today, this week, this month, or earlier.

The profile MUST be reported as not found when the viewer and the subject have blocked each other in either
direction, when same-gender visibility hides the subject, or when the subject is not Active.

#### Scenario: Blocked player's profile
- **GIVEN** player A blocked player B
- **WHEN** B opens A's profile
- **THEN** the response is "not found", and nothing indicates that a block exists

#### Scenario: Suspended player's profile
- **GIVEN** player B is suspended
- **WHEN** player A opens B's profile
- **THEN** the response is "not found"

### Requirement: Profile photo
A player SHALL be able to upload one profile photo in JPEG, PNG or WebP format, up to 5 MB. The system SHALL
resize it and serve it under an unguessable URL. An admin SHALL be able to remove a photo.

#### Scenario: Oversized photo
- **WHEN** a player uploads an 8 MB photo
- **THEN** the upload is rejected

### Requirement: Last-active tracking
The system SHALL record a player's last activity at most once every 15 minutes while the player makes
authenticated requests. The system SHALL expose last activity only through the coarse indicator.

#### Scenario: Coarse indicator
- **GIVEN** a player was last active 3 days ago
- **WHEN** another player views the profile
- **THEN** the indicator is "this week" and no timestamp is returned

### Requirement: Deleted and anonymised profiles
When an account is deleted, its profile SHALL be anonymised: display name «کاربر حذف‌شده», photo, bio and
birth date removed, and the profile excluded from every listing. Past matches and conversations SHALL show the
anonymised name.

#### Scenario: Match history after deletion
- **GIVEN** player B deleted their account
- **WHEN** player A views a past match with B
- **THEN** B is shown as «کاربر حذف‌شده» without a photo
