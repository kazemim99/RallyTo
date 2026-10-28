Design the complete mobile UI/UX for **Rallyto (رالیتو)**, a partner-finding app for racket sports in Iran.

## Product
Players find someone at their level to play with, at a club, at a time that suits them both. The app is not for clubs and does not book courts. It only connects players.

- **Sports:** tennis (تنیس), padel (پدل, doubles only), badminton (بدمینتون, singles and doubles) and squash (اسکواش, singles only).
- **Matching** uses three things:
  - **skill level**, which players declare themselves;
  - **gender**, which can be filtered;
  - **a club and a time window**, never a person's location: "Esteghlal club, Tehran, Saturdays 18:00–24:00".
- **Users:** adults only (18+). Players sign in with their mobile number and an SMS code.

## Platform and style
- An Android-first mobile app. Design at 360×800 and check 412×915.
- **Language:** the whole UI is in Persian, right-to-left (RTL), using the **Vazirmatn** font and Persian digits (۰۱۲۳). Dates use the Jalali calendar (۱۴۰۵/۰۸/۰۲), times are 24-hour (۱۹:۰۰), and the week starts on Saturday (شنبه).
- **Tone:** sporty, friendly, trustworthy and calm. It should not look like a dating app. The focus is the game, the club and the time.
- **Design system first:** colour tokens (a sporty primary such as court green or clay orange, neutrals, success, warning and error), a type scale, spacing, radius and elevation, light mode (dark mode is optional), and components:
  - buttons, inputs, chips, segmented controls and switches;
  - cards and list items, bottom sheets, dialogs, toasts and banners;
  - badges and tabs, avatars, empty states and skeleton loaders.
- Every screen needs **loading, empty and error states**, and inline validation messages in Persian.
- Navigation is a **bottom tab bar** with 5 tabs: خانه (Home), جستجو (Search), بازی‌های من (My matches), گفتگوها (Chats, with an unread badge), پروفایل (Profile). A notification bell with a badge sits in the Home header.

## Key concepts (use these terms consistently)
- **Levels.** Five per sport: مبتدی (Beginner), متوسط رو به پایین (Lower intermediate), متوسط (Intermediate), پیشرفته (Advanced), حرفه‌ای (Professional). Each level has a one-line description that depends on the sport.
- **Experience:** کمتر از ۶ ماه، ۶ تا ۱۲ ماه، ۱ تا ۳ سال، ۳ تا ۵ سال، بیش از ۵ سال.
- **Goals:** تمرین رالی، بازی دوستانه، رقابتی، آمادگی جسمانی.
- **Format:** یک‌نفره (singles) or دونفره (doubles).
- **Availability window** («زمان آزاد»). A player says when and where they are free:
  - either recurring weekdays or one date up to 60 days ahead;
  - a time range in 30-minute steps of at least 60 minutes;
  - 1 to 3 clubs in one city, and the formats.
  - A player can have up to 10 windows. Each must be reconfirmed every 30 days («هنوز آزادید؟»), otherwise it pauses.
- **Play post** («آگهی بازی»). A public game with open spots: sport, format, club, date, start time, duration, level range, partner gender (any, male or female), whether the court is booked, and an optional cost note and description.
- **Invitation** («دعوت»). A private game sent to specific players.
- **Match states:** باز (open, taking players), در انتظار (pending), قطعی (confirmed), انجام‌شده (completed), مورد اختلاف (disputed), تأییدنشده (unconfirmed), لغوشده (cancelled), منقضی (expired).
- **Participant states:** میزبان (host), دعوت‌شده (invited), درخواست داده (requested), پذیرفته (accepted), رد شده (declined), انصراف (left), حذف‌شده (removed).
- **Late cancellation.** Leaving or cancelling a confirmed game less than 12 hours before the start counts against your reliability. Always warn the player before they confirm.
- **Reputation:**
  - a star average per sport (shown only after 3 ratings; before that «بازیکن جدید»);
  - the top 3 tags;
  - a level statement, for example «بیشتر هم‌بازی‌ها می‌گویند بهتر از سطح اعلام‌شده بازی می‌کند»;
  - a **reliability badge**: تازه‌وارد (new) or خوش‌قولی: کم / خوب / عالی. Never show a number.
- **Visibility.** «همه» (everyone) or «فقط هم‌جنس» (same gender only). A same-gender player is shown only to, and only sees, players of their own gender.
- **Privacy.** Players never see each other's phone number or birth date. Age is shown as a range (۱۸–۲۴، ۲۵–۳۴، ۳۵–۴۴، ۴۵–۵۴، ۵۵+), and last activity as a bucket (امروز، این هفته، این ماه، قبل‌تر).

## Screens and flows

### 1. Welcome and sign-in
- **Splash**, then a **welcome** carousel (2–3 slides): find a partner at your level, at your club, at your time.
- **Phone entry:** an Iranian mobile number (۰۹۱۲…), a «دریافت کد» button, and a short terms and 18+ note.
- **Code entry:** a 4-digit code, auto-submit on the fourth digit, a resend countdown of 60 seconds, «تغییر شماره», and errors for a wrong or expired code and for too many attempts (blocked for an hour).
- **Account notices:** suspended until a date with the reason; banned.

### 2. Onboarding (6 steps, progress «مرحله ۲ از ۶»)
1. **Display name** (2–30 characters).
2. **Gender:** مرد / زن, with a clear lock notice: «بعداً قابل تغییر نیست».
3. **Birth date:** Jalali day, month and year selectors, with the 18+ rule and an inline error if under 18.
4. **City:** province, then city, searchable.
5. **Sport profiles.** Pick one or more sports. For each, the level as selectable cards showing the sport-specific description, the experience, the formats allowed for that sport, and the goals.
6. **Home clubs** (optional): pick clubs in the city that offer the chosen sports, or «فعلاً نه».

Finish on Home.

### 3. Home
- Greeting and quick actions: «پیدا کردن هم‌بازی», «ثبت آگهی بازی», «زمان آزاد من».
- **Upcoming games:** the next confirmed or open games as cards.
- **Pending actions:** invitations to answer, join requests to review if you are a host, attendance questions, and rating prompts.
- **Nudges:** reconfirm a stale availability window; finish the profile.

### 4. Search («جستجوی هم‌بازی»)
- **Filter bottom sheet:**
  - sport;
  - city (defaults to the profile city) and up to 5 clubs;
  - weekdays (chips starting شنبه) or a single date;
  - a time range;
  - a level range (defaults to your level ±1);
  - gender (locked to your own if you are same-gender only);
  - format;
  - result type: هر دو / بازیکن / آگهی.
- **Results:**
  - **open posts first** (page 1 only), each with sport, club, Jalali day and time, level range, open spots, host and «درخواست پیوستن»;
  - then **player cards**: avatar, name, age range, level and experience, last active, reliability badge, stars, the **overlapping window** highlighted («شنبه‌ها ۱۸:۰۰–۲۰:۳۰، باشگاه استقلال»), shared clubs, and the actions «دعوت به بازی» and «پیام»;
  - a «نتایج بیشتر» paging button.
- **Save this search:** a name and an alerts on/off switch.
- **Saved searches** (up to 5, show «۳ از ۵»): an alerts switch, delete, and run.
- **Empty state** with suggestions: widen the time, the level or the clubs.

### 5. Availability («زمان‌های آزاد من»)
- A list grouped by status (active, paused, expired) with a reconfirm banner.
- **Create and edit form:**
  - sport;
  - recurring (weekday chips) or one-off (Jalali date);
  - a time range picker in 30-minute steps;
  - 1–3 clubs in one city;
  - formats;
  - an optional note.
- **Actions:** pause, resume, «هنوز آزادم» (reconfirm) and delete.
- **Validation:** overlaps an existing window, more than 10 windows, a time in the past, at least 60 minutes.

### 6. Play posts and invitations
- **Create a post:** sport, format, club, Jalali date, start time, duration (60–240 min), players you bring, level range, partner gender, court booked, cost note and description. Show the open spots as you edit.
- **Direct invitation** from a player's profile: choose an existing open post of yours or a new game, plus an optional message (≤200 characters).
- **Limits:** up to 5 open posts; the start must be between 30 minutes and 30 days ahead.

### 7. Match detail (the most important screen)
- **Header:** sport, status chip, club, Jalali day and time to end time, duration, level range, court booked, cost note, description.
- **Players list** with their states; host actions on requests (accept or decline) with an "out of my level" badge.
- **Context actions by role and state:**
  - join with a message; withdraw a request; accept or decline an invitation;
  - leave, with the late-cancellation warning;
  - **host:** invite players, confirm early, remove a participant, edit (time and place lock once someone has joined), cancel with a reason (with the late-cancellation warning), copy or regenerate the share link, and share through the Android share sheet.
- **Cancel reason** shown on cancelled games.
- A link to the **group chat** for doubles games with 3 or more players.
- **After the game** (a 72-hour window):
  - the attendance card: «بازی انجام شد» / «بازی انجام نشد», and with «انجام شد» a way to mark other players as no-shows;
  - then the result: completed, disputed or unconfirmed, and each player's outcome (حاضر، غایب، مورد اعتراض).
- **Rate your partners:** a list of players you can still rate, within 7 days.
- **Report this post** from the overflow menu.

### 8. Rating («امتیازدهی»)
- 1–5 stars.
- Up to 3 tags from: وقت‌شناس، خوش‌برخورد، داوری منصفانه، رالی خوب، روحیه ورزشی، هماهنگی خوب.
- Required level accuracy: کمتر از سطح اعلام‌شده / درست / بیشتر.
- An optional private note (≤500 characters) clearly labelled «فقط مدیران می‌بینند».
- An explainer: ratings are double-blind (revealed when the other player rates, or after 7 days) and cannot be edited.

### 9. My matches («بازی‌های من»)
- Tabs: پیش‌رو (upcoming) and گذشته (past), as cards with status chips.
- Open a game from a pasted share link.

### 10. Chats («گفتگوها»)
- Tabs: گفتگوها and درخواست‌ها (message requests), each with an unread badge. Group chats show the game's sport and club as their title.
- **Conversation:**
  - bubbles with sending, failed (retry) and «خوانده شد» states;
  - «پیام حذف شد» for deleted messages; long press to delete your own or report someone else's;
  - date separators in Jalali;
  - a **safety notice** on new conversations: meet only at clubs, don't share personal details, use block and report;
  - a mute toggle.
- **Message request rules.** First contact with a stranger is a request: the sender can send exactly one message (≤500 characters) until it is accepted.
  - The recipient sees «پذیرفتن / نادیده گرفتن / مسدود کردن».
  - The sender sees a waiting state.
  - Players who share a game skip the request.
- **Read-only footer** when you can no longer reply (blocked or deleted account): «دیگر نمی‌توانید در این گفتگو پیام بفرستید».

### 11. Profiles
- **Another player's profile:**
  - photo, name, age range, city, bio, last active, member since;
  - per sport: level with its description, experience, formats, goals, and **reputation** (stars and count, or «بازیکن جدید», top tags, level statement);
  - the reliability badge and home clubs;
  - actions: «دعوت به بازی», «پیام»;
  - an overflow menu with block, report player and report photo.
  - A hidden or blocked player shows the same «بازیکن پیدا نشد» as a missing one.
- **My profile:**
  - edit name, bio, photo (from the gallery, cropped square), city, sport profiles, home clubs and visibility;
  - my reputation summary; blocked players; «گزارش‌های من» (each open or resolved, never the action taken);
  - notification settings; sign out; delete my account (confirmed with a fresh SMS code).

### 12. Report flow («گزارش»)
- Reached from a player, a message, a post or a photo.
- **Reasons:** آزار و مزاحمت، محتوای نامناسب، پروفایل جعلی، هرزنامه یا تبلیغات، رفتار ناامن یا غیبت‌های مکرر، کاربر زیر سن قانونی، سایر.
- Optional details (≤1000 characters) and a «این بازیکن را هم مسدود کن» checkbox.
- A confirmation that does not reveal any action.

### 13. Notifications
- **Inbox:** newest first, unread dots, mark all read; tapping opens the related game, chat, saved search, availability or profile.
- **Kinds:**
  - invitation, join request or answer, match confirmed, cancelled or expired, a player left or was removed;
  - a club no longer available;
  - the 2-hour reminder: «بازی تنیس شما امروز ساعت ۱۹:۰۰ در مجموعه تنیس استقلال»;
  - the attendance question, rating request and reminder, a saved-search alert, availability reconfirm or paused;
  - account notices.
- **Settings:**
  - push switches for بازی‌ها، گفتگو، امتیازها، جستجوهای ذخیره‌شده;
  - account notices always on (a disabled switch with an explanation);
  - **quiet hours** (default ۲۳:۰۰ تا ۰۸:۰۰, can span midnight, 30-minute steps, can be turned off).

## Deliverables
1. The design system page (tokens and components, RTL).
2. All screens above at 360×800, with their key states: empty, loading, error, and role variants of match detail (host and guest; open, confirmed and after the game).
3. Clickable prototype flows:
   - sign-in, then onboarding, then Home;
   - search, then a player, then an invitation, then the match;
   - post a game, then accept a request, then confirmed;
   - after the game: attendance, then rating;
   - a message request, then accepted, then the conversation;
   - a report with a block.

Keep tap targets at least 48dp, colour contrast at WCAG AA, and numbers and times in Persian digits everywhere.
