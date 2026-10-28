## ADDED Requirements

### Requirement: Iranian mobile number normalisation
The system SHALL accept an Iranian mobile number in any of these forms: `09xxxxxxxxx`, `9xxxxxxxxx`,
`989xxxxxxxxx`, `+989xxxxxxxxx`, `00989xxxxxxxxx`. Persian and Arabic-Indic digits are allowed. The system SHALL
normalise the number to E.164 (`+989xxxxxxxxx`) before any other processing. The system MUST reject any number
that is not an Iranian mobile number.

#### Scenario: Persian digits are normalised
- **WHEN** a client submits `۰۹۱۲۳۴۵۶۷۸۹`
- **THEN** the system treats it as `+989123456789`

#### Scenario: Landline number is rejected
- **WHEN** a client submits `02188776655`
- **THEN** the system rejects the request with a validation error and sends no SMS

### Requirement: Request a sign-in code
The system SHALL send a 4-digit one-time code by SMS to a valid mobile number. The code SHALL be valid for 5
minutes, and only its hash SHALL be stored. Per phone number, the system MUST enforce a 60-second resend
cooldown and at most 3 sends per 10 minutes. Over the limit, it SHALL answer with "too many requests" and the
number of seconds until the next allowed attempt. If the SMS provider fails, the system SHALL cancel that code
and return an error.

#### Scenario: First code request
- **WHEN** a client requests a code for `+989123456789` for the first time
- **THEN** an SMS with a 4-digit code is sent
- **AND** the response states that the code expires in 5 minutes

#### Scenario: Resend inside the cooldown
- **GIVEN** a code was sent to the number 30 seconds ago
- **WHEN** the client requests another code
- **THEN** the request is rejected as too many requests, with a retry-after of 30 seconds

#### Scenario: Fourth send inside ten minutes
- **GIVEN** three codes were sent to the number in the last 10 minutes
- **WHEN** the client requests a fourth code
- **THEN** the request is rejected as too many requests and no SMS is sent

#### Scenario: SMS provider failure
- **WHEN** the SMS provider returns an error for a code request
- **THEN** the code is cancelled and cannot be used
- **AND** the client receives an error saying the code could not be sent

### Requirement: Verify the code and sign in
The system SHALL sign the user in when the latest unexpired code for that number is submitted correctly.
- A new number SHALL get a new account with role Player, status Active and no profile.
- On success the system SHALL issue an access token valid for 60 minutes and a refresh token valid for 30 days.
- A code SHALL be usable once.
- After 5 wrong attempts on a code, the number SHALL be blocked from verification for 1 hour.

#### Scenario: New user signs in
- **GIVEN** no account exists for `+989123456789` and a valid code was sent
- **WHEN** the client submits the correct code
- **THEN** an account is created with role Player and status Active
- **AND** the response contains an access token, a refresh token and `profileCompleted = false`

#### Scenario: Returning user signs in
- **GIVEN** an active account with a completed profile exists for the number
- **WHEN** the client submits the correct code
- **THEN** the existing account is signed in and the response contains `profileCompleted = true`

#### Scenario: Wrong code five times
- **GIVEN** a valid code was sent
- **WHEN** the client submits a wrong code 5 times
- **THEN** further verification for that number is rejected for 1 hour, even with the correct code

#### Scenario: Expired code
- **GIVEN** a code was sent 6 minutes ago
- **WHEN** the client submits it
- **THEN** verification fails with "code expired"

#### Scenario: Code reuse
- **GIVEN** a code was already used to sign in
- **WHEN** the same code is submitted again
- **THEN** verification fails

### Requirement: Suspended, banned and deleted accounts cannot sign in
The system MUST refuse sign-in for an account that is Suspended (until the suspension ends) or Banned.
- A suspended user SHALL be told the suspension end date.
- A phone number recorded as banned MUST NOT be able to create a new account.
- A number whose account was deleted without a ban SHALL be able to register a new, empty account.

#### Scenario: Suspended user tries to sign in
- **GIVEN** an account suspended until 1405/09/01
- **WHEN** the user submits a correct code
- **THEN** sign-in is refused, and the response says the account is suspended until 1405/09/01

#### Scenario: Banned number tries to register again
- **GIVEN** the account for `+989123456789` was banned
- **WHEN** a correct code for that number is submitted
- **THEN** no account is created and sign-in is refused

#### Scenario: Re-registration after deletion
- **GIVEN** the account for a number was deleted and never banned
- **WHEN** a correct code for that number is submitted
- **THEN** a new account is created with no profile, matches, messages or ratings from the deleted account

### Requirement: Refresh token rotation
The system SHALL exchange a valid refresh token for a new access token and a new refresh token, and invalidate
the presented token. If a refresh token that was already rotated is presented again, the system MUST revoke
every token of that session family, and the user MUST sign in again.

#### Scenario: Normal refresh
- **WHEN** the client presents a valid refresh token
- **THEN** it receives a new access token and a new refresh token
- **AND** the old refresh token no longer works

#### Scenario: Stolen token replay
- **GIVEN** refresh token R1 was rotated to R2
- **WHEN** R1 is presented again
- **THEN** the request is rejected and R2 is revoked as well

### Requirement: Account status is enforced on every request
Every authenticated API request and realtime connection MUST be checked against the account's current status.
Requests from accounts that are not Active MUST be rejected no later than 60 seconds after the status change,
even when the access token has not expired.

#### Scenario: Suspension takes effect immediately
- **GIVEN** a signed-in player with a valid access token
- **WHEN** an admin suspends the account
- **THEN** the player's next API request after at most 60 seconds is rejected as unauthorised
- **AND** the player's realtime connection is closed

### Requirement: Roles
Every account SHALL have the Player role. The Admin role SHALL grant access to the admin panel and admin APIs.
- An account whose phone number is in the configured initial-admin list SHALL receive the Admin role on its
  first sign-in.
- Admins SHALL be able to grant and revoke the Admin role.
- The system MUST always keep at least one active admin.

#### Scenario: Initial admin
- **GIVEN** `+989121111111` is in the initial-admin list
- **WHEN** that number signs in for the first time
- **THEN** the account has the roles Player and Admin

#### Scenario: Player calls an admin API
- **WHEN** an account without the Admin role calls an admin endpoint
- **THEN** the request is rejected as forbidden

#### Scenario: Last admin cannot be removed
- **GIVEN** exactly one active admin exists
- **WHEN** that admin's Admin role is revoked
- **THEN** the request is rejected

### Requirement: Admin panel sign-in
The admin panel SHALL sign in with an email and a password, and SHALL admit only accounts with the Admin role.
The panel account SHALL be created from server configuration, never from the repository. Five wrong passwords
in a row SHALL lock password sign-in for 15 minutes. A wrong email and a wrong password SHALL get the same
answer. Players SHALL keep signing in with the SMS code, and a phone sign-in SHALL never grant the Admin role.

#### Scenario: Admin signs in
- **WHEN** the configured admin enters their email and password
- **THEN** a session with the Admin role is issued

#### Scenario: Wrong password five times
- **GIVEN** five wrong passwords in a row
- **WHEN** the admin enters the right password
- **THEN** sign-in is refused for 15 minutes

#### Scenario: Player at the admin panel
- **WHEN** an account without the Admin role tries to sign in to the admin panel
- **THEN** the admin panel refuses access

### Requirement: Sign out
The system SHALL revoke the session's refresh token on sign-out.

#### Scenario: Sign out
- **WHEN** a signed-in user signs out
- **THEN** the refresh token of that session no longer works

### Requirement: Account deletion
A player SHALL be able to delete their own account after confirming with a fresh sign-in code. Deletion
SHALL:
- set the account status to Deleted;
- revoke all refresh tokens;
- trigger the effects owned by the other capabilities: profile anonymised, future matches left or cancelled,
  device tokens revoked, messages shown as from "deleted user".

Deletion MUST NOT remove a ban record.

#### Scenario: Player deletes the account
- **GIVEN** a player confirms deletion with a valid fresh code
- **WHEN** the deletion completes
- **THEN** the account cannot sign in or call any API
- **AND** the player no longer appears in search, profiles or play posts

#### Scenario: Deletion without confirmation
- **WHEN** a deletion request carries no valid fresh code
- **THEN** the account is not deleted

### Requirement: Account status changes by admins
The system SHALL support these admin-driven status changes, each recorded with the admin, time and reason:
- suspend until a date;
- lift a suspension;
- ban permanently.

A ban SHALL record a peppered hash of the phone number for re-registration checks. A suspension SHALL end
automatically at its end date. Every status change SHALL be published to the other capabilities.

#### Scenario: Suspension expires
- **GIVEN** an account suspended until yesterday
- **WHEN** the user submits a correct sign-in code today
- **THEN** sign-in succeeds and the account is Active

#### Scenario: Ban records the phone hash
- **WHEN** an admin bans an account
- **THEN** the account status is Banned and the phone hash is stored in the ban list

### Requirement: Phone number privacy
The phone number SHALL be returned only to the account owner and to admins. No player-facing endpoint, push
payload or realtime event SHALL include another user's phone number. Logs MUST mask phone numbers and codes.

#### Scenario: Viewing another player's profile
- **WHEN** a player fetches another player's profile
- **THEN** the response contains no phone number

### Requirement: Production configuration guard
The host MUST refuse to start in Production when any of these is true:
- a sandbox code (`OTP_SANDBOX_CODE`) is configured;
- the JWT signing key is a placeholder;
- the SMS provider is a sandbox.

#### Scenario: Sandbox code in production
- **WHEN** the host starts with environment Production and `OTP_SANDBOX_CODE` set
- **THEN** startup fails with a configuration error
