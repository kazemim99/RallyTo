## ADDED Requirements

### Requirement: In-app notification inbox
Every notification except chat messages and message requests SHALL be stored in the recipient's inbox before
any push is attempted. The inbox SHALL:
- list notifications newest first, with paging;
- show an unread count;
- allow marking one or all as read;
- keep notifications for 90 days.

Chat messages and message requests are surfaced by the chat unread counts instead.

#### Scenario: Inbox without push
- **GIVEN** a player has no registered device
- **WHEN** they receive a join request
- **THEN** the notification appears in their inbox with an unread count of 1

### Requirement: Notification catalog
The system SHALL send these notifications, each with a Persian title and body and a deep link to the related
screen:

| Event | Recipient | Category |
|---|---|---|
| Invitation received | invitee | matches |
| Invitation accepted or declined | host | matches |
| Join request received | host | matches |
| Join request accepted or declined | requester | matches |
| Match confirmed | all accepted participants | matches |
| Match cancelled, participant left or removed, match expired | affected participants | matches |
| Venue of a future match hidden | participants | matches |
| Match reminder, 2 hours before start | accepted participants | matches |
| Attendance question at match end | accepted participants | ratings |
| Rating request and day-5 reminder | Played participants | ratings |
| Saved-search alert | saved-search owner | saved searches |
| Availability "still available?" and auto-pause | window owner | matches |
| New chat message or message request (push only) | conversation members | chat |
| Warning, suspension, gender correction | affected player | account |

#### Scenario: Join request notification
- **WHEN** a player requests to join a host's post
- **THEN** the host gets an inbox notification and a push, both opening the request screen

#### Scenario: Match reminder
- **GIVEN** a Confirmed match starts at 19:00
- **WHEN** it is 17:00
- **THEN** every accepted participant receives a reminder

### Requirement: Push delivery through Firebase Cloud Messaging
The system SHALL send push notifications through Firebase Cloud Messaging to every active device token of the
recipient. A token that FCM reports as invalid SHALL be revoked. A push failure MUST NOT remove or alter the
inbox entry.

#### Scenario: Invalid token
- **GIVEN** a player has two device tokens, and FCM reports one as unregistered
- **WHEN** a push is sent
- **THEN** that token is revoked, and the other device still receives the push

### Requirement: Device token registration
The app SHALL register its FCM token after sign-in and whenever the token changes. A token SHALL belong to one
account at a time, so registering it for another account moves it. Sign-out SHALL unregister the device's
token. Suspension, ban and deletion SHALL revoke all of the account's tokens.

#### Scenario: Shared phone, new user
- **GIVEN** a device token is registered to account A
- **WHEN** account B signs in on the same device and registers the token
- **THEN** the token belongs to B, and A no longer receives pushes on that device

### Requirement: Notification preferences
A player SHALL be able to turn push on or off for each of these categories: matches, chat, ratings, saved
searches. Account notifications (warnings, suspensions, gender corrections) MUST always be delivered. Turning a
category off SHALL stop push notifications only; inbox entries are still created.

#### Scenario: Saved-search pushes off
- **GIVEN** a player turned off pushes for saved searches
- **WHEN** a saved-search alert is raised
- **THEN** it appears in the inbox and no push is sent

### Requirement: Quiet hours
Each player SHALL have quiet hours in Tehran time, by default 23:00–08:00, which they can change or turn off.
During quiet hours, push notifications SHALL be suppressed and only the inbox entry created. Two kinds of
notification are exempt and always pushed:
- match reminders;
- notices that a match starting within 12 hours was cancelled or changed.

#### Scenario: Saved-search alert at night
- **GIVEN** quiet hours of 23:00–08:00
- **WHEN** a saved-search alert is raised at 01:00
- **THEN** no push is sent and the alert waits in the inbox

#### Scenario: Cancellation at night
- **GIVEN** quiet hours of 23:00–08:00
- **WHEN** at 23:30 a host cancels a match starting at 09:00
- **THEN** the participants receive a push immediately

### Requirement: No duplicate notifications
The same source event MUST NOT create more than one notification for the same recipient, even when the event
is delivered more than once.

#### Scenario: Event redelivered
- **GIVEN** a match-confirmed event was already processed
- **WHEN** the same event is delivered again
- **THEN** no second notification is created

### Requirement: Real-time inbox updates
A player who is online SHALL receive new notifications and the updated unread count over the realtime
connection, without polling.

#### Scenario: Live badge
- **GIVEN** a player has the app open
- **WHEN** they receive an invitation
- **THEN** the notification badge updates immediately

### Requirement: Persian content
Notification text SHALL be in Persian, with Persian digits and Jalali dates in Tehran time.

#### Scenario: Reminder text
- **WHEN** a reminder is sent for a match on 1405/08/02 at 19:00
- **THEN** the body reads, for example, «بازی تنیس شما امروز ساعت ۱۹:۰۰ در مجموعه تنیس استقلال»
