## ADDED Requirements

### Requirement: One direct conversation per pair
A player SHALL be able to open a direct conversation with another player from a profile, a search result, a
post or a match. Each pair of players SHALL have at most one direct conversation, which is reused. Opening it
MUST be rejected when the two players have blocked each other in either direction, or when same-gender
visibility hides one from the other.

#### Scenario: Open a conversation from search
- **WHEN** player A opens a conversation with player B from a search result
- **THEN** the existing A–B conversation is returned, or a new one is created

#### Scenario: Hidden by same-gender visibility
- **GIVEN** player B has visibility Same gender only and a different gender from player A
- **WHEN** A tries to open a conversation with B
- **THEN** the request is rejected as "player not found"

### Requirement: Message requests for first contact
A direct conversation SHALL start as a message request for the recipient unless one of these holds:
- the two players share a match where both are Accepted, Confirmed or Completed;
- the recipient accepted this conversation before;
- the recipient started the conversation.

While the conversation is a request:
- the sender SHALL be able to send exactly one message of up to 500 characters, and further messages MUST be
  rejected;
- the recipient SHALL see the conversation in a separate Requests list and can accept it, ignore it or block
  the sender;
- ignoring SHALL hide the request without telling the sender;
- accepting SHALL turn it into a normal conversation for both players.

#### Scenario: First message from a stranger
- **GIVEN** players A and B have never shared a match
- **WHEN** A sends B «سلام، شنبه‌ها استقلال بازی می‌کنی؟»
- **THEN** B sees it under Requests and receives a message-request notification

#### Scenario: Second message before acceptance
- **GIVEN** A's first message to B is still a request
- **WHEN** A sends another message
- **THEN** the message is rejected with "wait until your request is accepted"

#### Scenario: Recipient ignores
- **WHEN** B ignores A's request
- **THEN** the request leaves B's Requests list, and A sees no change and cannot send more

#### Scenario: Recipient accepts
- **WHEN** B accepts A's request
- **THEN** both can send messages freely

#### Scenario: Shared match skips the request
- **GIVEN** A accepted B's join request for a post
- **WHEN** B messages A
- **THEN** the conversation is a normal conversation, not a request

### Requirement: Match group conversations
A match with a capacity above 2 (doubles or padel) SHALL get a group conversation once at least 2 players are
Accepted. Its members SHALL follow the match:
- Accepted participants join it.
- Participants who leave or are removed lose access to new messages, and keep the history up to that point.

Singles matches SHALL use the direct conversation of the two players.

#### Scenario: Padel group chat
- **GIVEN** a padel post where the host has accepted two players
- **WHEN** the third accepted player joins
- **THEN** all accepted players are members of the match conversation

#### Scenario: Leaving the match
- **WHEN** a participant leaves a padel match
- **THEN** they stop receiving messages from its group conversation

### Requirement: Sending messages
A member SHALL be able to send a text message of 1–1000 characters. Leading and trailing whitespace is
trimmed, and whitespace-only messages MUST be rejected.
- Each message SHALL carry a client-generated id, and retrying with the same id MUST NOT create a duplicate.
- Messages SHALL be delivered in real time to members who are online.
- Members who are offline SHALL receive a push notification, unless they muted the conversation or turned off
  chat pushes.
- A player MUST NOT send more than 30 messages per minute or start more than 20 new direct conversations per
  day.

#### Scenario: Real-time delivery
- **GIVEN** B has the app open
- **WHEN** A sends a message in their conversation
- **THEN** B receives it in real time without refreshing

#### Scenario: Retry does not duplicate
- **WHEN** the client sends the same message twice with the same client id after a timeout
- **THEN** the conversation contains the message once

#### Scenario: Offline recipient
- **GIVEN** B has no live connection and chat pushes are on
- **WHEN** A sends a message
- **THEN** B receives a push notification

### Requirement: Read state and unread counts
A member SHALL be able to mark a conversation as read up to a message. In a direct conversation, the other
member SHALL see which of their messages were read. Each member SHALL see unread counts per conversation and in
total. Message requests SHALL be counted separately.

#### Scenario: Read receipt
- **WHEN** B opens the conversation and reads A's last message
- **THEN** A sees that message as read

### Requirement: Conversation history
Members SHALL be able to load history newest first, 50 messages per page, with a cursor. Non-members MUST NOT
be able to read a conversation.

#### Scenario: Non-member access
- **WHEN** a player requests the messages of a conversation they are not a member of
- **THEN** the response is "not found"

### Requirement: Blocking in chat
After a block between two players, the system SHALL apply these rules:
- neither SHALL be able to send messages in their direct conversation;
- the direct conversation SHALL disappear from the blocker's list;
- the blocked player SHALL see that they cannot reply, without being told about a block;
- in a shared group conversation, the blocked player's messages SHALL be hidden for the blocker.

#### Scenario: Blocked player tries to reply
- **GIVEN** A blocked B
- **WHEN** B sends a message in their direct conversation
- **THEN** the message is rejected with "you can no longer reply to this conversation"

### Requirement: Deleting a message
A sender SHALL be able to delete their own message for everyone. A deleted message SHALL show as «پیام حذف شد».
A report filed earlier SHALL keep its snapshot of the original text.

#### Scenario: Delete after a report
- **GIVEN** B reported A's message
- **WHEN** A deletes the message
- **THEN** members see «پیام حذف شد», and the admin still sees the original text in the report

### Requirement: Inactive members
Members whose account is Suspended, Banned or Deleted MUST NOT be able to send messages. Their earlier
messages SHALL remain. A deleted account's messages SHALL show the sender as «کاربر حذف‌شده».

#### Scenario: Conversation with a deleted user
- **GIVEN** B deleted their account
- **WHEN** A opens their conversation
- **THEN** B's messages remain, shown as from «کاربر حذف‌شده», and A cannot send new messages

### Requirement: Muting
A member SHALL be able to mute a conversation. A muted conversation still delivers messages and counts as
unread, but produces no push notification.

#### Scenario: Muted group
- **GIVEN** a member muted a match group conversation
- **WHEN** a new message arrives while they are offline
- **THEN** no push is sent, and the unread count increases

### Requirement: Safety notice in new conversations
When a player opens a new direct conversation or a message request, the app SHALL show a short safety notice:
- meet only at clubs;
- do not share personal details;
- use block and report when needed.

#### Scenario: First conversation with a player
- **WHEN** a player opens a new conversation for the first time
- **THEN** the safety notice is shown above the messages
