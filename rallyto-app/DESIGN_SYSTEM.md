# Rallyto design system (Flutter)

This is the guide for the agents who will redesign each screen. It covers the approved Figma Make design and how this app builds it. The design reference is in `../docs/design/figma-export/`: `index.css` holds the tokens and component CSS, and `App.tsx` holds every screen. Use it as a visual reference only. Do not port the React or Tailwind code.

Everything below already exists in code:

- tokens and themes are in `lib/config/theme/`;
- components are in `lib/core/widgets/`, all exported from `widgets.dart`;
- the bottom bar shell is in `lib/config/routes/main_shell.dart`;
- tests are in `test/config/theme/`, `test/core/widgets/components_test.dart` and `test/config/routes/`.

---

## 1. Tokens

### Colour

The light theme is the design target. A few design values fell short of WCAG AA (4.5:1). We darkened those slightly, and kept the hue. Every text/background pair is pinned in `test/config/theme/app_theme_test.dart`, for both themes.

| Token | Light | Design value | Why it changed | Dark (derived) |
|---|---|---|---|---|
| primary | `#146B52` | same | White text on it is 6.45:1. | `#6FCFAE`, with onPrimary `#062A1F` |
| primaryDark | `#0B4C3A` | same | Hero gradient end, dark covers, completion card. | same (white text) |
| primarySoft | `#E7F3EF` | same | Soft fills, secondary buttons, the overlap box, the player's own chat bubble. | `#183A30` |
| onPrimarySoft | `#0B4C3A` | `.bubble.mine` | Text in the player's own chat bubble. | `#9FE3C9` |
| primarySoftBorder | `#B8D8CD` | same | Secondary button border. | `#2F5C4E` |
| accent | `#E9783C` | same | **Fills only.** Text on it is ink (5.45:1), never white (2.91:1). This includes the unread badge. | same, with ink text |
| accentSoft | `#FFF0E7` | same | | `#3D2A1E` |
| ink | `#172522` | same | onSurface. | `#E3ECE9` |
| muted | `#61706D` | `#687875` | The design value is 4.34:1 on the canvas. | `#A3B3AE` |
| line | `#DCE5E2` | same | 1px borders and dividers. | `#2E3D39` |
| outline | `#7D8A87` | none | Borders that must be seen (3:1), such as the switch track when off. | `#6F7E7A` |
| surface | `#FFFFFF` | same | Cards, sheets, the nav bar. | `#17211E` |
| canvas | `#F5F8F7` | same | Scaffold and AppBar background. | `#0F1715` |
| track | `#E9EFED` | `.segment` | Segmented control track. | `#22302C` |
| success | `#147C5A` | `#16835F` | Darkened to reach 4.55:1 on primarySoft (the green chip). | `#5FD0A0` |
| warning | `#A65B17` | `#A85C18` | Darkened to reach 4.57:1 on accentSoft. | `#F2B27A` |
| error / errorSoft | `#C33B3B` / `#FDEAEA` | `#C53C3C` | Darkened to reach 4.52:1 on errorSoft. | `#FF8A80` / `#3D1F1F` |
| info / infoSoft | `#315F84` / `#EAF2FA` | same | Safety and info notes. | `#9CC5EA` / `#1E2E3D` |
| blue / blueSoft | `#2F6AAA` / `#E8F0FA` | same | The blue quick-action tile. | `#8AB6EA` / `#1E2C3E` |
| navInactive | `#6E7876` | `#83908D` | The design value is 3.31:1 on white. | `#8E9B97` |
| ball / onBall | `#D9EF70` / `#315215` | same | The sport-ball badge. | same |
| brandStart → brandEnd | primary → primaryDark | `.hero` | The brand gradient. It is the same green in both themes, with white text. | same |
| onBrandMuted | `#CCE6DD` | `.eyebrow.light` | Secondary text on the brand gradient (4.89:1). | same |
| star / rating | `#F5BD3D` / `#9A6A05` | `.rating` | The star fill and the score text. | `#F2C46B` text |

Orange text and icons on accentSoft use **warning**, not accent. The accent on its soft fill is only 2.6:1.

### Reading colours: `context.palette`

```dart
import 'package:rallyto_app/config/theme/app_palette.dart';

final palette = context.palette;           // AppPalette, a ThemeExtension
Text('…', style: TextStyle(color: palette.muted));
```

The `ColorScheme` agrees with the palette:

- `primary`/`onPrimary` is the green with white text.
- `secondary` is the accent, with `onSecondary` set to ink.
- `primaryContainer` is primarySoft, and `secondaryContainer` is accentSoft.
- `tertiary` and `tertiaryContainer` are the info blue.
- `surface` is white; `onSurfaceVariant` is muted; `outlineVariant` is line.
- `error` and `errorContainer` are the error pair.
- `surfaceContainer*` are pale greens. Muted text stays above 4.5:1 on every one of them.

**Never hard-code a hex value in a widget.** If a colour is missing, add it to `AppColors` and `AppPalette` (both themes), then add its pair to the theme test.

### Radii (`AppRadius`)

| Token | Value | Used for |
|---|---|---|
| sm | 10 | segments, tooltips |
| md | 16 | cards, menus, notices |
| lg | 24 | hero, sheets, dialogs |
| button | 14 | buttons, OTP boxes |
| field | 13 | inputs, search box, segment track |
| card | 16 | `AppCard` |
| tile | 14 | list rows, stat grid, bio, info boxes |
| chip / full | 999 | chips, badges |

### Spacing (`AppSpacing`, 4dp grid)

The scale is `xxs 4 · xs 8 · sm 12 · md 16 · lg 24 · xl 32 · xxl 48`.

- `screen` (16) is the side padding of every screen.
- `section` (24) is the gap above each `SectionTitle`.

`AppSizes` holds the fixed heights: control 50 (buttons, inputs, search), navBar 64, progressBar 5, badge 18. `AppTouchTarget.min` is 48. `AppIconSize` holds icon sizes: xs 14, sm 16, meta 17, action 20, nav 23, md 24, hero 72.

### Typography (`AppTypography`, applied as the theme's `TextTheme`)

The app keeps the bundled **Vazir** font, the same family as the design's Vazirmatn. It works offline. Vazir has no 800 weight, so 800 renders as 700.

| Design | Size / weight / line height | Use |
|---|---|---|
| hero title `.hero h2` | 27 / 700 / 1.55 | `displaySmall` |
| h1, screen title | 24 / 800 / 1.45 | `headlineMedium` |
| greeting `.home-head h1` | 20 / 800 / 1.45 | `headlineSmall` |
| section `h2` | 18 / 700 / 1.5 | `titleLarge` |
| AppBar title `.topbar strong` | 17 / 700 | `AppBarTheme.titleTextStyle` |
| card title `h3` | 16 / 700 / 1.5 | `titleMedium` |
| emphasis `b`, `.lead` | 14 / 700 / 1.6 | `titleSmall` |
| inputs, lead body | 14 / 400 / 1.6 | `bodyLarge` |
| body `p` | 13 / 400 / **1.8**, muted | `bodyMedium` + `palette.muted` |
| small, meta | 12 / 400 / 1.7 | `bodySmall` |
| button | 15 / 700 | `labelLarge` |
| field label `.label`, tile label | 12 / 700 | `labelMedium` |
| chip, nav label, caption | 11 / 500 | `labelSmall` |

`bodyMedium` stays ink because it is also the default for every unstyled `Text`. Where the design shows grey body copy, write `theme.textTheme.bodyMedium?.copyWith(color: context.palette.muted)`.

### Component themes (already in `AppTheme`)

- **Buttons:** 50dp minimum height, radius 14, bold 15.
  - `FilledButton` is primary.
  - `OutlinedButton` is the design's secondary (primarySoft fill with a primarySoftBorder border).
  - `TextButton` is ghost (48dp minimum).
- **Inputs:** white fill, 1px line border, radius 13, about 50dp tall, a 1.5px green border when focused, muted hint and label text.
- **Cards:** white, 1px line border, radius 16, no elevation. `AppCard` adds the soft shadow.
- **Chips:** pill shape. Selected is a primary fill with white text; unselected is white with a line border.
- **Switch:** white thumb. The track is primary when on and outline when off.
- **AppBar:** canvas background, centred bold 17 title, no elevation or tint, 64dp tall.
- **Other surfaces:**
  - bottom sheets: surface, top radius 24, line-coloured drag handle;
  - dialogs: radius 24;
  - snackbars: floating, radius 14, on ink;
  - dividers: line colour, 1px;
  - badges: ink text on the accent.

---

## 2. Component catalog

Import everything with `import 'package:rallyto_app/core/widgets/widgets.dart';`.

Every component follows these rules:

- RTL layout, using `EdgeInsetsDirectional` and `AlignmentDirectional`;
- tap targets of at least 48dp;
- Persian semantics labels;
- colours from the theme and palette only.

Each entry below shows the constructor, then a one-line example.

### Buttons

**AppButton** follows the design's `.button` variants.

```dart
AppButton({required String label, required VoidCallback? onPressed, AppButtonVariant variant = primary,
  bool loading = false, bool expanded = true, bool compact = false, IconData? icon})
AppButton.secondary(...) · AppButton.ghost(...) · AppButton.danger(...) · AppButton.inverse(...)
AppButton.text(...)        // = ghost (kept for existing pages)
AppButton.destructive(...) // = danger (kept for existing pages)
```

`AppButtonVariant` has the values `primary, secondary, ghost, danger, inverse`. `AppButtonVariant.text` and `.destructive` are aliases, so existing pages still compile.

- `compact` makes the button 48dp with 12pt text, for card actions and banner buttons.
- `inverse` is a white button with green text, for the hero and dark covers.
- `loading` shows a spinner, keeps the size and ignores taps.

```dart
AppButton(label: 'دعوت به بازی', icon: Icons.send_rounded, onPressed: _invite)
```

**DashedButton** is the design's `.new-game`: a 50dp button with a dashed green border.

```dart
DashedButton({required String label, required VoidCallback? onPressed, IconData? icon = Icons.add_rounded})
DashedButton(label: 'ساخت بازی جدید', onPressed: () => context.push(Routes.matchNew))
```

**StickyActions** is the design's `.sticky-actions`: a bottom-pinned row, secondary : primary = 1 : 1.5, over a fade into the canvas.

```dart
StickyActions({required Widget primary, Widget? secondary})   // StickyActions.contentPadding = 104
Scaffold(extendBody: true, bottomNavigationBar: StickyActions(secondary: AppButton.secondary(...), primary: AppButton(...)),
  body: ListView(padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, StickyActions.contentPadding), ...))
```

### Surfaces and rows

**AppCard** is the design's `.card`: white, a line border, radius 16, a soft shadow and 16dp padding. With `onTap`, the whole card is one button.

```dart
AppCard({required Widget child, VoidCallback? onTap, EdgeInsetsGeometry padding = 16, Color? color,
  Color? borderColor, double radius = 16, String? semanticLabel})
AppCard(onTap: () => context.push(Routes.matchPath(m.id)), child: MatchSummary(m))
```

**ListRow** is the design's `.list-row`: white, a line border, radius 14. The leading icon is coloured primary. Stack rows with 8dp gaps.

```dart
ListRow({required String title, String? subtitle, Widget? leading, Widget? trailing, Widget? titleTrailing,
  VoidCallback? onTap, String? semanticLabel})
ListRow(leading: const AppAvatar(name: 'مهدی'), title: 'مهدی نوری', titleTrailing: const AppChip(label: 'میزبان'), subtitle: 'متوسط · خوش‌قولی: عالی')
```

**MenuList** and **MenuItem** are the profile `.menu`: rows of at least 54dp, divided by lines, each ending in a forward chevron.

```dart
MenuList({required List<MenuItem> items, String? title})
MenuItem({required String label, required VoidCallback? onTap, IconData? icon, Widget? trailing, bool destructive = false, Key? key})
MenuList(items: [MenuItem(icon: Icons.star_outline_rounded, label: 'اعتبار و امتیازهای من', onTap: ...)])
```

**RadioCard** is one choice of a single-choice list, as in the design's `.selected-game` and `.level-card`. When selected it has a 2dp green border on primarySoft.

```dart
RadioCard({required String title, String? subtitle, required bool selected, required VoidCallback? onTap, Widget? trailing})
RadioCard(title: 'شنبه در باشگاه استقلال', subtitle: '۲ آبان · ۱۹:۰۰ تا ۲۰:۳۰', selected: true, onTap: ..., trailing: const AppChip(label: 'باز', tone: AppChipTone.green))
```

**AppSwitchRow** is the design's `.toggle-row`: a title, a muted subtitle and a switch. The whole row toggles.

```dart
AppSwitchRow({required String title, String? subtitle, required bool value, required ValueChanged<bool>? onChanged})
AppSwitchRow(title: 'زمین رزرو شده است', subtitle: 'فقط وضعیت رزرو را اعلام می‌کنید.', value: booked, onChanged: cubit.setBooked)
```

### Headers and status

**SectionTitle** is the design's `.section-title`: an 18-bold heading, an optional muted subtitle and an optional action link. It has 12dp below it; leave `AppSpacing.section` (24) above it.

```dart
SectionTitle({required String title, String? subtitle, String? actionLabel, VoidCallback? onAction})
SectionTitle(title: 'بازی بعدی', actionLabel: 'مشاهده همه', onAction: () => StatefulNavigationShell.of(context).goBranch(2))
```

**AppChip** is the design's `.chip`. Its tones are `neutral` (white with a line border), `active` (primary fill, white text), `green`, `orange`, `red` and `blue`. It takes an optional icon. With `onTap` it becomes a 48dp toggle.

```dart
AppChip({required String label, AppChipTone tone = neutral, IconData? icon, VoidCallback? onTap})
AppChip(label: 'خوش‌قولی: عالی', tone: AppChipTone.green, icon: Icons.verified_user_outlined)
```

**AppBadge** shows a count in Persian digits, in ink on the accent, 18dp tall. It shows «۹+» above `max` and nothing at zero. With `child`, the badge sits on the child's top-end corner. `AppBadge.text(count)` gives the badge's string.

```dart
AppBadge({required int count, int max = 9, Widget? child, String? semanticLabel})
AppBadge(count: unread, child: const Icon(Icons.notifications_outlined))
```

**NoticeBanner** is the design's notice. Its tones are:

- `brand`: `.notice-card`, a round white icon on primarySoft;
- `info`: `.info` and `.safety`, blue;
- `warning`: `.warning`, accentSoft;
- `success`: `.success-banner`;
- `error`: `.error-banner`.

It takes a title, a body and an optional compact secondary action.

```dart
NoticeBanner({NoticeTone tone = brand, String? title, String? body, IconData? icon, String? actionLabel, VoidCallback? onAction})
NoticeBanner(tone: NoticeTone.info, icon: Icons.shield_outlined, body: 'شماره تماس شما نمایش داده نمی‌شود. هماهنگی را در رالیتو انجام دهید.')
```

**StepHeader** and **AppProgressBar**:

- `AppProgressBar` is the design's `.progress`: 5dp, filling from the start side, read out as a percentage.
- `StepHeader` puts «مرحله ۲ از ۶» under the bar, after an optional label.

```dart
AppProgressBar({required double value, String? semanticLabel, double height = 5})
StepHeader({required int step, required int total, String? label})
StepHeader(step: 2, total: 3, label: 'جزئیات بازی')
```

### Brand, people and facts

**BrandMark** and **BrandTile** are the logo and the app tile. See [6. Brand](#6-brand).

**HeroCard** is the design's `.hero`: the brand gradient, radius 24, and the court-lines motif. The motif is a `CustomPainter`: a court outline rotated 12°, drawn in 15% white. The card has an eyebrow, a title and a CTA slot. `CourtLines` and `CourtLinesPainter` are public, so the sign-in art can reuse them.

```dart
HeroCard({required String title, String? eyebrow, Widget? cta, double minHeight = 220})
HeroCard(eyebrow: 'هم‌بازی مناسب، همین نزدیکی', title: 'در سطح خودت،\nدر باشگاه خودت.', cta: AppButton.inverse(label: 'پیدا کردن هم‌بازی', onPressed: ...))
```

**QuickActionTile** is one tile of `.quick-grid`. Its tones are `green`, `orange` and `blue`. Lay three tiles in a `Row` of `Expanded`, with 8dp gaps between them.

```dart
QuickActionTile({required IconData icon, required String label, String? caption, QuickActionTone tone = green, required VoidCallback? onTap})
QuickActionTile(icon: Icons.add_rounded, label: 'ثبت آگهی بازی', caption: 'بازیکن پیدا کن', tone: QuickActionTone.orange, onTap: ...)
```

**AppAvatar** is the design's `.avatar`: the name's initial on a soft green gradient, inside a 2px white ring. It shows the photo instead when there is one. Its sizes are `small` 30, `medium` 38 (the default), `large` 44 and `xlarge` 64.

```dart
AppAvatar({required String name, AppAvatarSize size = medium, String? photoUrl})
AppAvatar(name: player.displayName, photoUrl: player.photoUrl, size: AppAvatarSize.xlarge)
```

**AvatarStack** is the design's `.avatars`: avatars overlapping by 10dp, with a caption.

```dart
AvatarStack({required List<String> names, String? caption, AppAvatarSize size = medium, int maxVisible = 3})
AvatarStack(names: ['سام', 'علی'], caption: 'شما و علی رضایی')
```

**SportBall** is the design's `.sport-ball`: a ball-yellow circle with the sport's initial or symbol.

```dart
SportBall({required String label, String? semanticLabel, double size = 42})
SportBall(label: 'T', semanticLabel: sport.nameFa)
```

**MetaRow** and **MetaItem** are the design's `.meta`: small muted icon-and-text facts between a top and a bottom line.

```dart
MetaRow({required List<MetaItem> items, EdgeInsetsGeometry margin = vertical 12})
MetaRow(items: [MetaItem(venue.name, icon: Icons.place_outlined), MetaItem('متوسط · یک‌نفره')])
```

**StatGrid** and **StatItem** are the design's `.stat-grid`: equal columns divided by lines.

```dart
StatGrid({required List<StatItem> items})
StatGrid(items: [StatItem(label: 'مدت', value: '۹۰ دقیقه'), StatItem(label: 'سطح', value: 'متوسط ±۱'), StatItem(label: 'زمین', value: 'رزرو شده')])
```

**RangeDisplay** is the design's `.range`: a level range shown as two ends joined by a green bar. It is display only; open a picker from `onTap`.

```dart
RangeDisplay({required String start, required String end, VoidCallback? onTap})
RangeDisplay(start: 'متوسط رو به پایین', end: 'پیشرفته', onTap: _pickLevels)
```

### Inputs

**AppSegmented**, **AppSegment** is the design's `.segment`. The selected segment is white with bold primary text, on a `track` background. Each segment is a 50dp target.

```dart
AppSegmented<T>({required List<AppSegment<T>> segments, required T selected, required ValueChanged<T>? onChanged})
AppSegmented(segments: const [AppSegment(value: false, label: 'پیش‌رو'), AppSegment(value: true, label: 'گذشته')], selected: past, onChanged: cubit.showPast)
```

**SearchField** is the design's `.searchbox`: 50dp tall, with a search icon and a clear button.

```dart
SearchField({TextEditingController? controller, String hint = 'جستجو', ValueChanged<String>? onChanged,
  ValueChanged<String>? onSubmitted, VoidCallback? onCleared, bool autofocus = false, FocusNode? focusNode})
SearchField(hint: 'نام بازیکن یا باشگاه', onChanged: cubit.query)
```

**OtpBoxes** is the design's `.otp`: four 58×62 boxes, laid out LTR.

- Typing moves to the next box.
- Pasting, SMS autofill (`smsRetriever`) and the iOS one-time-code suggestion all fill the boxes.
- Persian and Arabic digits are converted to ASCII.
- `onCompleted` fires once every box is filled (auto-submit).

`features/auth/.../otp_input.dart` is the older version of this field. The sign-in screen agent should replace it with `OtpBoxes` and pass the same `smsRetriever`.

```dart
OtpBoxes({TextEditingController? controller, FocusNode? focusNode, int length = 4, bool enabled = true, bool autofocus = true,
  String? errorText, ValueChanged<String>? onCompleted, ValueChanged<String>? onChanged, SmsRetriever? smsRetriever, String semanticLabel})
OtpBoxes(onCompleted: (code) => bloc.add(CodeSubmitted(code)), errorText: state.error, smsRetriever: retriever)
```

`JalaliDateSelector` is unchanged. It still picks a Jalali date.

### States and feedback

**SkeletonBlock** and **SkeletonLines** are static, shimmer-free placeholder bars.

- `pulse: true` adds a gentle fade.
- The fade does not run when the player asked for less motion (`MediaQuery.disableAnimations`).
- `SkeletonLines` announces «در حال بارگذاری…» once.

```dart
SkeletonBlock({double? width, double height = 14, double radius = 8, bool pulse = false})
SkeletonLines({int count = 3, double lineHeight = 14, bool pulse = false})
StateSwitcher(status: s, loading: const Padding(padding: EdgeInsetsDirectional.all(16), child: SkeletonLines()), ...)
```

These four were restyled, and their APIs are unchanged:

- `EmptyState`: the icon in a primarySoft circle, a 16-bold title, a muted subtitle and a CTA.
- `ErrorState`: the icon in an errorSoft circle, the message, and a secondary retry button.
- `LoadingView`: a green spinner and a muted message.
- `StateSwitcher`.

**AppSnackbar** has the same API as before (`success`, `error`, `info`):

- success: ink background with a green check;
- error: the error colour;
- info: ink background.

**AppBottomNav** and **AppNavItem** make up the bar the shell uses. Screens never build it themselves.

```dart
AppBottomNav({required List<AppNavItem> items, required int currentIndex, required ValueChanged<int> onSelected})
```

---

## 3. Screen rules

1. **The scaffold is the canvas.** Use `Scaffold` with no background override: the theme sets it to canvas. The AppBar is canvas-coloured too. Its title is centred, bold, 17pt, with no elevation.
2. **Side padding is 16dp** (`AppSpacing.screen`) on every scrolling body: `ListView(padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 24))`.
3. **Sections:** put `SizedBox(height: AppSpacing.section)` (24) above each `SectionTitle`. The `SectionTitle` brings its own 12dp below.
4. **No hard-coded colours.** Use `Theme.of(context).colorScheme` and `context.palette` only. Never `Color(0x…)` or `Colors.amber`; ratings use `palette.star` and `palette.rating`.
5. **Use Directional layout only.** That means `EdgeInsetsDirectional`, `AlignmentDirectional`, `PositionedDirectional` and `BorderRadiusDirectional`. Use `start`/`end`, never `left`/`right`. Forward chevrons are `Icons.chevron_right_rounded`, which mirrors in RTL. Back arrows come from the AppBar.
6. **Digits and dates:**
   - Display every number in Persian digits with `PersianDigits.toPersian` / `fromInt` (`core/utils/persian_digits.dart`).
   - Normalise input with `PersianDigitsInputFormatter` before sending it to the API.
   - Write dates in Jalali with `JalaliFormatter` (`formatDate`, `formatDateTime`, `formatTime`, `formatShortDate`, `weekday`) or `DateFormatter`.
   - API dates go through `JalaliDateText`.
   - Never format a `DateTime` by hand.
7. **Tap targets of at least 48dp.** Icon buttons already meet this through the theme. Custom tappables need `ConstrainedBox(minHeight: 48)`.
8. **Every user-facing string goes in `AppStrings`** (`core/constants/app_strings.dart`) or the feature's `*_labels.dart`. Never inline text in a widget.
9. **Data screens show their loading, empty and error states** through `StateSwitcher`, or through `SkeletonLines`, `EmptyState` and `ErrorState` directly. Never leave a blank screen or an endless spinner.
10. **Keep the existing keys.** Widget `Key`s and their `static const Key …` names are what the page tests find. A restyle keeps them.
11. **Persian semantics:**
    - Icon-only buttons need a Persian `tooltip`.
    - Decorative graphics get `ExcludeSemantics`.
    - Tappable cards get a `semanticLabel` when their text does not say what the tap does.
12. **Sheets and pickers:** use `showModalBottomSheet(useRootNavigator: true, …)` to cover the bottom bar. A full-screen picker uses `Navigator.of(context, rootNavigator: true)`, as `CityPicker` and `VenuePicker` already do.
13. **Separators: never put a dot beside a digit.**
    - The design separates parts with «·», but in Persian a dot beside a digit reads as a zero: «بازیکن‌ها · ۱» looks like «۱۰».
    - Join display parts with `joinDisplay()` (`core/utils/display_join.dart`). It writes the bullet «•» between words and the Persian comma «،» when a digit touches the separator: «تنیس • انفرادی», «شنبه ۲ آبان، ۱۹:۰۰».
    - Counts go in parentheses: «پیش‌رو (۳)», «بازیکن‌ها (۱ از ۲)».
    - The `·` in the examples of this document is shorthand for `joinDisplay()`.
14. **Light only, and phone-shaped everywhere.**
    - The approved design has no dark version, so `MaterialApp` uses `ThemeMode.light` and ignores the device's dark mode. `AppTheme.dark` stays defined and tested for when a dark design exists.
    - On the web or a tablet, a window wider than 480dp shows the app in a centred 480dp column on a quiet backdrop (`AppViewportFrame`, applied once in `MaterialApp.builder`). A native phone is never framed.
    - Inside the column `MediaQuery` reports the column's size, so size things from `MediaQuery.sizeOf` or `LayoutBuilder`, never from the window.
    - Widget tests that run the whole app (`test/main_test.dart`) set a phone-sized window, because the default test window (800×600) counts as a tablet.

---

## 4. The navigation shell and the bottom bar

The signed-in app is a `StatefulShellRoute.indexedStack` (`lib/config/routes/app_router.dart`). It has five branches, laid out right to left. Each branch keeps its own stack and scroll position.

| Tab | Root | Other routes in the branch (where a `go` lands) |
|---|---|---|
| خانه | `Routes.home` | notifications, notification settings, availability list and forms, venue |
| جستجو | `Routes.search` | saved searches, player profile, invitation form |
| بازی‌های من | `Routes.matches` | `/matches/new`, match detail, rating form, `/m/:token` share links |
| گفتگوها | `Routes.chat` | conversation, `/players/:id/chat`, `/matches/:id/chat` |
| پروفایل | `Routes.profile` | blocked players, my reports, report form |

Navigation works like this:

- **`context.push(location)` stacks the page on the current tab**, whatever branch owns the route. A player's page opened from home stays in the home tab.
- **`context.go(location)` and cold deep links land in the owning tab.**
- To switch tabs from a screen, call `StatefulNavigationShell.of(context).goBranch(index)`. The tab order is home 0, search 1, matches 2, chat 3, profile 4.
- Tapping the current tab again pops it to its root.
- Sign-in (`/auth/phone`, `/auth/code`) and onboarding are outside the shell, so they have no bar.

**The bar shows** on the five tab roots and on the read-only pages reached from them:

- player profile and match detail (including `/m/:token`);
- venue detail and saved searches;
- availability list and notification inbox;
- my reports and blocked players.

**The bar is hidden** on the full-screen flows listed in `AppRouter.fullScreenRoutes`:

- the post game form (`/matches/new`);
- the invitation form;
- the availability forms (new and edit);
- the rating form and the report form;
- the conversation screen (`/chat/:id`, `/players/:id/chat`, `/matches/:id/chat`), which has its own composer;
- notification settings.

These flows are pushed **inside the current tab's stack**, and the shell hides the bar while one of them is on top. They are not pushed on the root navigator, because go_router 18 cannot push a shell route over a root-navigator route without building the shell twice. That fails on duplicate page keys, which `main_shell_test.dart` reproduces. The app does that in three places:

- a player's page opened from a conversation;
- the profile opened from a form;
- a push deep link that arrives while a form is open.

To add a full-screen route, put it in a branch and add its pattern to `fullScreenRoutes`.

**The chat badge** on گفتگوها comes from the one `ChatBadgeCubit`. The shell provides it, together with `NotificationBadgeCubit`, so home and the bar share one source:

- it reads `GET /conversations/unread`;
- it re-reads on every realtime `message.received`;
- it polls every 60s while the hub is down;
- it re-reads when the player leaves a chat screen or changes tab.

Any screen in the shell can `context.read<ChatBadgeCubit>()` or `context.read<NotificationBadgeCubit>()`.

---

## 5. Design screens → Flutter pages

| `App.tsx` screen | Flutter page(s) | Notes |
|---|---|---|
| `Home` | `features/home/presentation/pages/home_page.dart` | Greeting header with the bell (`AppBadge` from `NotificationBadgeCubit`), `HeroCard`, three `QuickActionTile`s, next game (`AppCard` + `SportBall`, `MetaRow`, `AvatarStack`), a brand `NoticeBanner`. The page still pushes tab roots (search, games, chats, profile) from list tiles. Switch those to `goBranch`, and drop the sign-out tile, which belongs in the profile `MenuList`. |
| `Search` | `features/search/presentation/pages/partner_search_page.dart`, `widgets/search_filter_sheet.dart`, `widgets/partner_result_card.dart`, `pages/saved_searches_page.dart` | `SearchField`, rows of `AppChip`s, filters in a sheet with `AppSegmented`, open posts and player cards (`AppAvatar` xlarge, an overlap box in primarySoft, card actions with `compact` buttons 1 : 1.5). |
| `Player` | `features/profile/presentation/pages/player_profile_page.dart`, `widgets/profile_widgets.dart`, `ratings/.../reputation_widgets.dart` | Profile hero (`AppAvatar` xlarge, a green chip), a bio box, a sport `AppCard`, home clubs as `ListRow`s, and `StickyActions` (message / invite). |
| `Invite` | `features/matches/presentation/pages/match_form_page.dart` (invitation mode, `/players/:id/invite`) | Invitee box in primarySoft, `RadioCard` game choices, `DashedButton` «ساخت بازی جدید», a message field with a counter, an info `NoticeBanner`. |
| `Post` | `match_form_page.dart` (post mode, `/matches/new`), `widgets/form_fields.dart` | `StepHeader`, field labels (`labelMedium`), `AppSegmented` format, `RangeDisplay` levels, `AppSwitchRow` court booked, an open-spots box. |
| `Match` (host and guest) | `features/matches/presentation/pages/match_detail_page.dart`, `widgets/match_card.dart` | A dark cover (`primaryDark`, white text), `StatGrid`, players as `ListRow`s with mini actions, a details `AppCard` with the cost line, success/warning `NoticeBanner`s, `StickyActions` for the host. |
| `Matches` | `features/matches/presentation/pages/my_matches_page.dart`, `widgets/match_card.dart` | `AppSegmented` (upcoming · count / past), status `AppChip`s, game cards, a dashed «paste a link» box. |
| `Chats` | `features/chat/presentation/pages/chat_inbox_page.dart` | `AppSegmented` (conversations · requests), chat rows (`AppAvatar` large or a group square, an `AppBadge` unread count), request cards with ghost/primary actions. |
| `Conversation` | `features/chat/presentation/pages/conversation_page.dart` | A safety `NoticeBanner` (info), date separators, bubbles (`theirs` white with a line border; `mine` primarySoft with `onPrimarySoft` text), and a composer with a 50dp green send button. There is no bar on this screen. |
| `Profile` | `features/profile/presentation/pages/my_profile_page.dart`, `widgets/sport_profile_editor.dart`, `pages/blocked_players_page.dart`, `reports/.../my_reports_page.dart` | A compact profile hero, a completion card (`primaryDark` with white text and a progress bar), `MenuList`, sign-out as a destructive `MenuItem`. |
| `DesignSystem` | This document and `lib/core/widgets/`; no screen | |
| `SignIn` | `features/auth/presentation/pages/phone_page.dart`, `code_page.dart`, `widgets/otp_input.dart` | Dark brand art with `CourtLines`, a white brand square holding the colour `BrandMark`, an LTR phone field, `OtpBoxes`, a resend link with a countdown, the terms line. |
| `Onboarding` | `features/onboarding/presentation/pages/onboarding_page.dart` | `StepHeader` «مرحله n از ۶», one question per step, `AppSegmented` (gender), a level `RadioCard`, home clubs as `ListRow`s with a check, a bottom action. |
| none (derive from the components) | `catalog/.../venue_detail_page.dart`, `availability/.../availability_list_page.dart` and `availability_form_page.dart`, `notifications/.../notification_inbox_page.dart` and `notification_preferences_page.dart`, `ratings/.../rating_form_page.dart`, `reports/.../report_form_page.dart` | Use the same vocabulary: `AppCard`, `ListRow`, `MenuList`, `AppSwitchRow`, `NoticeBanner`, `StickyActions`, `SectionTitle`. |

---

## 6. Brand

### The mark

The mark is the "rally loop": two tapered arcs close a ring. Each arc is one player's shot, in that player's colour, and it travels round to the ball that reaches the partner. The second arc and ball are the first turned 180°.

It has three styles (`BrandMarkStyle`):

- `reversed`, for green or dark backgrounds: white and ball yellow. The app tile uses it.
- `color`, for light backgrounds: court green and clay.
- `mono`, one colour (ink), for silhouettes.

Its colours are fixed brand values from `branding/mark.json`. They are not theme tokens and never change with the theme. Never recolour, stretch or redraw the mark, and never put a letter in its place.

### BrandMark and BrandTile

- `BrandMark` is the bare mark.
- `BrandTile` is the app icon: the rounded court-green gradient square (corner radius 23% of the side), with the reversed mark at 90%.

Both are painted by `BrandMarkPainter`, a `CustomPainter`, with no image or SVG, so they are sharp at any size. Both are decorative unless given a `semanticLabel`. The `rotation` parameters exist for the launch splash.

```dart
BrandMark({double size = 48, BrandMarkStyle style = color, String? semanticLabel, double rotationDegrees = 0})
BrandTile({double size = 96, String? semanticLabel, double markRotationDegrees = 0})
BrandMark(size: 61, style: BrandMarkStyle.color)   // on the sign-in art's white square
```

### The launch splash

`LaunchSplash` is applied once in `MaterialApp.builder`, above `AppViewportFrame`, so it covers the whole window. It plays once per app start. Its first frame is the native splash: the canvas with a 96dp `BrandTile` centred. The hand-off from the platform is therefore seamless.

| Time | What happens |
|---|---|
| 0–750 ms | The rally: the mark spins one full turn inside the tile and stops in its normal pose. The tile pops to 106% and back (650–850 ms). |
| 700–1100 ms | The tile glides up 36dp. «رالیتو» and the tagline fade and slide up beneath it. |
| 1100–1350 ms | Hold. |
| 1350–1600 ms | The overlay fades out, then leaves the tree. |

- The app is built underneath from the start and keeps running.
- The overlay takes no taps and is hidden from screen readers.
- With reduced motion (`MediaQuery.disableAnimations`) there is no overlay at all. The widget tests that run the whole app set reduced motion, so nothing waits on the splash.

### Native icons and splash screens: light only

The native screens are light, like the app.

- **Android launcher:** an adaptive icon (`mipmap-anydpi-v26/ic_launcher.xml`). The background is the tile gradient, the foreground is the reversed mark, and the monochrome layer is for themed icons.
- **Android launch screen:** `launch_background` is the canvas (`@color/splash_background`) with the 96dp `launch_mark` centred. Android 12+ shows the same canvas with `splash_icon`. The `values-night` styles repeat the light themes.
- **Android pushes:** FCM shows `ic_notification`, the white silhouette of the mark, tinted court green.
- **iOS:** `LaunchScreen.storyboard` has the canvas background, with the 96pt `LaunchImage` centred.

### Where the files come from

Every brand file comes from one source, `branding/mark.json`.

- `python branding/build_brand.py` writes the SVGs in `branding/`.
- With `--render`, it also renders every raster: launcher icons, the adaptive layers, the splash images, the notification icon, and the iOS app icon and launch image.

Never edit a raster or an SVG by hand. To change the mark, edit `mark.json`, re-run the script, and update the constants in `BrandMarkPainter`. `test/core/widgets/brand_mark_test.dart` fails until the painter matches `mark.json` again. `test/config/platform_config_test.dart` pins the native wiring.
