import 'dart:ui' show CheckedState, Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rallyto_app/config/theme/app_palette.dart';
import 'package:rallyto_app/config/theme/app_theme.dart';
import 'package:rallyto_app/core/constants/app_strings.dart';
import 'package:rallyto_app/core/widgets/widgets.dart';

/// The design system's shared components: their variants and tones in the design's colours, right-to-left layout,
/// 48dp tap targets, Persian digits and Persian semantics.
void main() {
  const light = AppPalette.light;

  Future<void> pump(WidgetTester tester, Widget child, {ThemeData? theme, bool reduceMotion = true}) async {
    if (reduceMotion) {
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
        disableAnimations: true,
      );
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    }
    await tester.pumpWidget(
      MaterialApp(
        theme: theme ?? AppTheme.light,
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: child),
          ),
        ),
      ),
    );
  }

  BoxDecoration decorationOf(WidgetTester tester, Finder container) =>
      tester.widget<Container>(container).decoration! as BoxDecoration;

  group('AppButton', () {
    test('the earlier variant names map to the design\'s', () {
      expect(AppButtonVariant.text, AppButtonVariant.ghost);
      expect(AppButtonVariant.destructive, AppButtonVariant.danger);
    });

    testWidgets('primary is filled green, 50dp tall', (tester) async {
      await pump(tester, AppButton(label: 'ثبت', onPressed: () {}));
      final button = find.byType(FilledButton);
      expect(tester.getSize(button).height, 50);
      final style = tester.widget<FilledButton>(button).style;
      // The theme supplies the colours; the button only sizes itself.
      expect(style?.backgroundColor, isNull);
      expect(Theme.of(tester.element(button)).colorScheme.primary, light.primary);
    });

    testWidgets('secondary is soft green with a green border and green text', (tester) async {
      await pump(tester, AppButton.secondary(label: 'پیام', onPressed: () {}));
      final style = tester.widget<OutlinedButton>(find.byType(OutlinedButton)).style!;
      expect(style.backgroundColor?.resolve({}), light.primarySoft);
      expect(style.foregroundColor?.resolve({}), light.primary);
      expect(style.side?.resolve({})?.color, light.primarySoftBorder);
    });

    testWidgets('.text is the ghost button and .destructive the danger one; both keep working', (tester) async {
      var taps = 0;
      await pump(
        tester,
        Column(
          children: [
            AppButton.text(label: 'رد کردن', onPressed: () => taps++),
            AppButton.destructive(label: 'لغو بازی', onPressed: () => taps++),
            AppButton(label: 'حذف', variant: AppButtonVariant.destructive, onPressed: () => taps++),
          ],
        ),
      );
      expect(find.widgetWithText(TextButton, 'رد کردن'), findsOneWidget);
      final danger = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'لغو بازی'));
      expect(danger.style?.backgroundColor?.resolve({}), light.error);
      expect(danger.style?.foregroundColor?.resolve({}), light.onError);
      await tester.tap(find.text('رد کردن'));
      await tester.tap(find.text('لغو بازی'));
      await tester.tap(find.text('حذف'));
      expect(taps, 3);
    });

    testWidgets('compact is 48dp; the icon option and inverse variant render', (tester) async {
      await pump(
        tester,
        Column(
          children: [
            AppButton(label: 'ارسال دعوت', onPressed: () {}, icon: Icons.send, compact: true),
            AppButton.inverse(label: 'پیدا کردن هم‌بازی', onPressed: () {}),
          ],
        ),
      );
      expect(tester.getSize(find.widgetWithText(FilledButton, 'ارسال دعوت')).height, 48);
      expect(find.byIcon(Icons.send), findsOneWidget);
      final inverse = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'پیدا کردن هم‌بازی'));
      expect(inverse.style?.backgroundColor?.resolve({}), light.onBrand);
      expect(inverse.style?.foregroundColor?.resolve({}), light.brandStart);
    });

    testWidgets('loading keeps the size, shows a spinner and ignores taps', (tester) async {
      var taps = 0;
      await pump(tester, AppButton.secondary(label: 'ذخیره', onPressed: () => taps++, loading: true));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(tester.getSize(find.byType(OutlinedButton)).height, 50);
      await tester.tap(find.byType(OutlinedButton));
      expect(taps, 0);
    });
  });

  group('AppCard', () {
    testWidgets('is white with a line border and 16dp padding; tappable as one button', (tester) async {
      final semantics = tester.ensureSemantics();
      var taps = 0;
      await pump(
        tester,
        AppCard(onTap: () => taps++, semanticLabel: 'بازی شنبه', child: const Text('تنیس در استقلال')),
      );
      final material = tester.widget<Material>(
        find.descendant(of: find.byType(AppCard), matching: find.byType(Material)),
      );
      expect(material.color, light.surface);
      expect((material.shape! as RoundedRectangleBorder).side.color, light.line);
      final padding = tester.widget<Padding>(
        find.ancestor(of: find.text('تنیس در استقلال'), matching: find.byType(Padding)).first,
      );
      expect(padding.padding, const EdgeInsetsDirectional.all(16));
      await tester.tap(find.text('تنیس در استقلال'));
      expect(taps, 1);
      expect(find.bySemanticsLabel(RegExp('بازی شنبه')), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('without onTap there is no ink', (tester) async {
      await pump(tester, const AppCard(child: Text('x')));
      expect(find.byType(InkWell), findsNothing);
    });
  });

  group('AppChip', () {
    testWidgets('each tone uses its fill and AA text colour', (tester) async {
      await pump(
        tester,
        const Wrap(
          children: [
            AppChip(label: 'عادی'),
            AppChip(label: 'انتخاب‌شده', tone: AppChipTone.active),
            AppChip(label: 'قطعی', tone: AppChipTone.green),
            AppChip(label: '۲ جای خالی', tone: AppChipTone.orange),
            AppChip(label: 'لغو', tone: AppChipTone.red),
            AppChip(label: 'اطلاع', tone: AppChipTone.blue),
          ],
        ),
      );
      Color fill(String label) =>
          decorationOf(tester, find.ancestor(of: find.text(label), matching: find.byType(Container)).first).color!;
      Color text(String label) => tester.widget<Text>(find.text(label)).style!.color!;
      expect(fill('عادی'), light.surface);
      expect(text('عادی'), light.ink);
      expect(fill('انتخاب‌شده'), light.primary);
      expect(text('انتخاب‌شده'), light.onPrimary);
      expect(fill('قطعی'), light.primarySoft);
      expect(text('قطعی'), light.success);
      expect(fill('۲ جای خالی'), light.accentSoft);
      expect(text('۲ جای خالی'), light.warning);
      expect(fill('لغو'), light.errorSoft);
      expect(text('لغو'), light.error);
      expect(fill('اطلاع'), light.infoSoft);
      expect(text('اطلاع'), light.info);
    });

    testWidgets('a tappable chip is a 48dp selected/unselected button with its icon', (tester) async {
      var taps = 0;
      await pump(
        tester,
        AppChip(label: 'تنیس', tone: AppChipTone.active, icon: Icons.sports_tennis, onTap: () => taps++),
      );
      expect(tester.getSize(find.byType(InkWell)).height, greaterThanOrEqualTo(48));
      expect(find.byIcon(Icons.sports_tennis), findsOneWidget);
      await tester.tap(find.text('تنیس'));
      expect(taps, 1);
      final semantics = tester.getSemantics(find.text('تنیس'));
      expect(semantics.flagsCollection.isSelected, Tristate.isTrue);
    });
  });

  group('AppAvatar and AvatarStack', () {
    testWidgets('the initial on the green gradient in a 2px white ring, read out as the name', (tester) async {
      await pump(tester, const AppAvatar(name: 'علی رضایی', size: AppAvatarSize.xlarge));
      expect(find.text('ع'), findsOneWidget);
      final box = find.ancestor(of: find.text('ع'), matching: find.byType(Container)).first;
      expect(tester.getSize(box), const Size(64, 64));
      final decoration = decorationOf(tester, box);
      expect((decoration.border! as Border).top.width, 2);
      expect((decoration.border! as Border).top.color, light.surface);
      expect(decoration.gradient, isA<LinearGradient>());
      expect(find.bySemanticsLabel('علی رضایی'), findsOneWidget);
    });

    testWidgets('sizes are 30, 38, 44 and 64; an empty name shows «؟»', (tester) async {
      expect([for (final s in AppAvatarSize.values) s.dimension], [30, 38, 44, 64]);
      expect(AppAvatar.initialOf('  '), '؟');
      await pump(tester, const AppAvatar(name: 'سام', photoUrl: 'https://example.invalid/a.jpg'));
      expect(find.byType(Image), findsOneWidget, reason: 'a photo, with the initial as its fallback');
    });

    testWidgets('a stack overlaps by 10dp from the start side, then the caption', (tester) async {
      await pump(tester, const AvatarStack(names: ['سام', 'علی', 'مهدی', 'رضا'], caption: 'شما و علی رضایی'));
      expect(find.byType(AppAvatar), findsNWidgets(3), reason: 'three at most');
      final first = tester.getTopRight(find.byType(AppAvatar).at(0));
      final second = tester.getTopRight(find.byType(AppAvatar).at(1));
      expect(first.dx - second.dx, 28, reason: 'RTL: each next avatar 38 - 10 further left');
      expect(find.text('شما و علی رضایی'), findsOneWidget);
    });
  });

  group('AppBadge', () {
    testWidgets('a count in Persian digits, ink on the accent, 18dp; «۹+» beyond nine', (tester) async {
      await pump(tester, const Column(children: [AppBadge(count: 3), AppBadge(count: 12)]));
      expect(find.text('۳'), findsOneWidget);
      expect(find.text('۹+'), findsOneWidget);
      final text = tester.widget<Text>(find.text('۳'));
      expect(text.style?.color, light.onAccent, reason: 'never white on the accent');
      final box = find.ancestor(of: find.text('۳'), matching: find.byType(Container)).first;
      expect(decorationOf(tester, box).color, light.accent);
      expect(tester.getSize(box).height, 18);
      expect(find.bySemanticsLabel(AppStrings.unreadCount('۳')), findsOneWidget);
    });

    testWidgets('nothing at zero; on a child it sits on the top end corner (left in RTL)', (tester) async {
      await pump(tester, const AppBadge(count: 0));
      expect(find.byType(Container), findsNothing);

      await pump(tester, const AppBadge(count: 2, child: Icon(Icons.chat_bubble_outline, size: 24)));
      final icon = tester.getCenter(find.byType(Icon));
      final badge = tester.getCenter(find.text('۲'));
      expect(badge.dx, lessThan(icon.dx));
      expect(badge.dy, lessThan(icon.dy));
    });
  });

  testWidgets('SectionTitle: a header, its subtitle, and an action link', (tester) async {
    var taps = 0;
    await pump(
      tester,
      SectionTitle(
        title: 'بازی بعدی',
        subtitle: 'نزدیک‌ترین زمان‌ها',
        actionLabel: 'مشاهده همه',
        onAction: () => taps++,
      ),
    );
    expect(find.text('نزدیک‌ترین زمان‌ها'), findsOneWidget);
    expect(tester.getSize(find.byType(TextButton)).height, greaterThanOrEqualTo(48));
    await tester.tap(find.text('مشاهده همه'));
    expect(taps, 1);
    expect(tester.getSemantics(find.text('بازی بعدی')).flagsCollection.isHeader, isTrue);
  });

  testWidgets('AppSegmented: the selected segment is white with bold green text; taps choose', (tester) async {
    var value = 'single';
    await pump(
      tester,
      StatefulBuilder(
        builder: (context, setState) => AppSegmented<String>(
          segments: const [
            AppSegment(value: 'single', label: 'یک‌نفره'),
            AppSegment(value: 'double', label: 'دونفره'),
          ],
          selected: value,
          onChanged: (v) => setState(() => value = v),
        ),
      ),
    );
    final selectedText = tester.widget<Text>(find.text('یک‌نفره'));
    expect(selectedText.style?.color, light.primary);
    expect(selectedText.style?.fontWeight, FontWeight.w700);
    expect(tester.getSize(find.byType(GestureDetector).first).height, greaterThanOrEqualTo(48));
    expect(tester.getCenter(find.text('یک‌نفره')).dx, greaterThan(tester.getCenter(find.text('دونفره')).dx));

    await tester.tap(find.text('دونفره'));
    await tester.pump();
    expect(value, 'double');
    expect(tester.getSemantics(find.bySemanticsLabel('دونفره')).flagsCollection.isSelected, Tristate.isTrue);
  });

  group('NoticeBanner', () {
    testWidgets('every tone pairs its fill with its text colour', (tester) async {
      await pump(
        tester,
        const Column(
          children: [
            NoticeBanner(title: 'برند', body: 'متن برند'),
            NoticeBanner(tone: NoticeTone.info, body: 'متن اطلاع'),
            NoticeBanner(tone: NoticeTone.warning, body: 'متن هشدار'),
            NoticeBanner(tone: NoticeTone.success, title: 'موفق'),
            NoticeBanner(tone: NoticeTone.error, body: 'متن خطا'),
          ],
        ),
      );
      Color fill(String text) =>
          decorationOf(tester, find.ancestor(of: find.text(text), matching: find.byType(Container)).last).color!;
      Color color(String text) => tester.widget<Text>(find.text(text)).style!.color!;
      expect(fill('متن برند'), light.primarySoft);
      expect(color('متن برند'), light.muted);
      expect(fill('متن اطلاع'), light.infoSoft);
      expect(color('متن اطلاع'), light.info);
      expect(fill('متن هشدار'), light.accentSoft);
      expect(color('متن هشدار'), light.warning);
      expect(fill('موفق'), light.primarySoft);
      expect(fill('متن خطا'), light.errorSoft);
      expect(color('متن خطا'), light.error);
    });

    testWidgets('the brand tone has a round white icon and an optional action', (tester) async {
      var taps = 0;
      await pump(
        tester,
        NoticeBanner(
          title: 'هنوز شنبه‌ها آزادید؟',
          body: 'بازهٔ زمانی شما ۲ روز دیگر متوقف می‌شود.',
          actionLabel: 'هنوز آزادم',
          onAction: () => taps++,
        ),
      );
      await tester.tap(find.text('هنوز آزادم'));
      expect(taps, 1);
      final circle = find.ancestor(of: find.byType(Icon), matching: find.byType(Container)).first;
      expect(decorationOf(tester, circle).shape, BoxShape.circle);
      expect(decorationOf(tester, circle).color, light.surface);
    });
  });

  testWidgets('HeroCard: the brand gradient, the court lines, eyebrow, title and CTA', (tester) async {
    await pump(
      tester,
      HeroCard(
        eyebrow: 'هم‌بازی مناسب، همین نزدیکی',
        title: 'در سطح خودت، در باشگاه خودت.',
        cta: AppButton.inverse(label: 'پیدا کردن هم‌بازی', onPressed: () {}),
      ),
    );
    final card = find.byType(HeroCard);
    expect(tester.getSize(card).height, greaterThanOrEqualTo(220));
    final decoration = decorationOf(tester, find.descendant(of: card, matching: find.byType(Container)).first);
    expect((decoration.gradient! as LinearGradient).colors, [light.brandStart, light.brandEnd]);
    expect(decoration.borderRadius, BorderRadius.circular(24));
    final painter = tester
        .widget<CustomPaint>(find.descendant(of: find.byType(CourtLines), matching: find.byType(CustomPaint)))
        .painter;
    expect(painter, isA<CourtLinesPainter>());
    expect((painter! as CourtLinesPainter).color, light.onBrand.withValues(alpha: 0.15));
    expect(find.text('پیدا کردن هم‌بازی'), findsOneWidget);
    expect(const CourtLinesPainter(Colors.white).shouldRepaint(const CourtLinesPainter(Colors.black)), isTrue);
  });

  testWidgets('QuickActionTile: a tinted icon, bold label and caption, one button', (tester) async {
    var taps = 0;
    await pump(
      tester,
      Row(
        children: [
          Expanded(
            child: QuickActionTile(
              icon: Icons.add,
              label: 'ثبت آگهی بازی',
              caption: 'بازیکن پیدا کن',
              tone: QuickActionTone.orange,
              onTap: () => taps++,
            ),
          ),
        ],
      ),
    );
    expect(tester.getSize(find.byType(QuickActionTile)).height, greaterThanOrEqualTo(128));
    expect(tester.widget<Icon>(find.byIcon(Icons.add)).color, light.warning);
    expect(find.bySemanticsLabel('ثبت آگهی بازی، بازیکن پیدا کن'), findsOneWidget);
    await tester.tap(find.byType(QuickActionTile));
    expect(taps, 1);
  });

  testWidgets('SportBall: the sport initial on the ball colour, read out as the sport', (tester) async {
    await pump(tester, const SportBall(label: 'T', semanticLabel: 'تنیس'));
    final text = tester.widget<Text>(find.text('T'));
    expect(text.style?.color, light.onBall);
    expect(decorationOf(tester, find.byType(Container)).color, light.ball);
    expect(find.bySemanticsLabel('تنیس'), findsOneWidget);
  });

  testWidgets('MetaRow: muted icon+text items between a top and a bottom line', (tester) async {
    await pump(
      tester,
      const MetaRow(
        items: [
          MetaItem('مجموعه تنیس استقلال', icon: Icons.place_outlined),
          MetaItem('متوسط ‏•‏ یک‌نفره'),
        ],
      ),
    );
    expect(find.byIcon(Icons.place_outlined), findsOneWidget);
    expect(tester.widget<Text>(find.text('متوسط ‏•‏ یک‌نفره')).style?.color, light.muted);
    final border = decorationOf(tester, find.byType(Container).first).border! as Border;
    expect(border.top.color, light.line);
    expect(border.bottom.color, light.line);
  });

  testWidgets('StatGrid: three columns divided by lines, each read out as label: value', (tester) async {
    await pump(
      tester,
      const StatGrid(
        items: [
          StatItem(label: 'مدت', value: '۹۰ دقیقه'),
          StatItem(label: 'سطح', value: 'متوسط ±۱'),
          StatItem(label: 'زمین', value: 'رزرو شده'),
        ],
      ),
    );
    expect(find.byType(VerticalDivider), findsNWidgets(2));
    expect(find.bySemanticsLabel('مدت: ۹۰ دقیقه'), findsOneWidget);
    expect(tester.getCenter(find.text('مدت')).dx, greaterThan(tester.getCenter(find.text('زمین')).dx));
  });

  testWidgets('ListRow: leading, title, subtitle and trailing; a tappable row is at least 48dp', (tester) async {
    var taps = 0;
    await pump(
      tester,
      ListRow(
        leading: const Icon(Icons.place_outlined),
        title: 'مجموعه تنیس استقلال',
        subtitle: 'تهران، میدان ونک',
        trailing: const AppChip(label: 'باز', tone: AppChipTone.green),
        onTap: () => taps++,
      ),
    );
    expect(tester.widget<Text>(find.text('تهران، میدان ونک')).style?.color, light.muted);
    expect(tester.getSize(find.byType(ListRow)).height, greaterThanOrEqualTo(48));
    expect(tester.getCenter(find.byIcon(Icons.place_outlined)).dx, greaterThan(tester.getCenter(find.text('باز')).dx));
    await tester.tap(find.byType(ListRow));
    expect(taps, 1);
  });

  testWidgets('AppProgressBar and StepHeader: 5dp, filled from the start, «مرحله ۲ از ۶»', (tester) async {
    await pump(tester, const SizedBox(width: 300, child: StepHeader(step: 2, total: 6)));
    expect(find.text('مرحله ۲ از ۶'), findsOneWidget);
    expect(tester.getSize(find.byType(AppProgressBar)).height, 5);
    final fill = find.descendant(of: find.byType(AppProgressBar), matching: find.byType(DecoratedBox)).last;
    final bar = tester.getRect(find.byType(AppProgressBar));
    final filled = tester.getRect(fill);
    expect(filled.width, closeTo(bar.width / 3, 0.5));
    expect(filled.right, bar.right, reason: 'RTL: from the right');

    await pump(tester, const AppProgressBar(value: 0.55));
    expect(tester.getSemantics(find.byType(AppProgressBar)).value, AppStrings.progressPercent('۵۵'));
  });

  testWidgets('StickyActions: secondary and primary in a 1 : 1.5 ratio', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            extendBody: true,
            body: const SizedBox.expand(),
            bottomNavigationBar: StickyActions(
              secondary: AppButton.secondary(label: 'پیام', onPressed: () {}),
              primary: AppButton(label: 'دعوت به بازی', onPressed: () {}),
            ),
          ),
        ),
      ),
    );
    final secondary = tester.getSize(find.byType(OutlinedButton)).width;
    final primary = tester.getSize(find.byType(FilledButton)).width;
    expect(primary / secondary, closeTo(1.5, 0.01));
    expect(tester.getCenter(find.text('پیام')).dx, greaterThan(tester.getCenter(find.text('دعوت به بازی')).dx));
  });

  testWidgets('SearchField: a 50dp box with a hint; the clear button empties it', (tester) async {
    final changes = <String>[];
    var cleared = 0;
    await pump(tester, SearchField(hint: 'نام بازیکن یا باشگاه', onChanged: changes.add, onCleared: () => cleared++));
    expect(find.text('نام بازیکن یا باشگاه'), findsOneWidget);
    expect(tester.getSize(find.byType(TextField)).height, greaterThanOrEqualTo(50));
    expect(find.byTooltip(AppStrings.clearSearch), findsNothing);

    await tester.enterText(find.byType(TextField), 'علی');
    await tester.pump();
    await tester.tap(find.byTooltip(AppStrings.clearSearch));
    await tester.pump();
    expect(changes, ['علی', '']);
    expect(cleared, 1);
    expect(find.byTooltip(AppStrings.clearSearch), findsNothing);
  });

  testWidgets('AppSwitchRow: the whole row toggles, read out as one switch', (tester) async {
    var value = true;
    await pump(
      tester,
      StatefulBuilder(
        builder: (context, setState) => AppSwitchRow(
          title: 'زمین رزرو شده است',
          subtitle: 'فقط وضعیت رزرو را اعلام می‌کنید.',
          value: value,
          onChanged: (v) => setState(() => value = v),
        ),
      ),
    );
    await tester.tap(find.text('زمین رزرو شده است'));
    await tester.pump();
    expect(value, isFalse);
    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(value, isTrue);
    expect(tester.getSize(find.byType(AppSwitchRow)).height, greaterThanOrEqualTo(48));
    final node = tester.getSemantics(find.byType(Switch));
    expect(node.label, contains('زمین رزرو شده است'));
  });

  group('OtpBoxes', () {
    testWidgets('four LTR boxes; a typed or pasted code (any digits) completes once, in ASCII', (tester) async {
      final completed = <String>[];
      await pump(tester, OtpBoxes(onCompleted: completed.add));
      await tester.pump();
      expect(
        Directionality.of(
          tester.element(find.descendant(of: find.byType(OtpBoxes), matching: find.byType(EditableText))),
        ),
        TextDirection.ltr,
      );
      await tester.enterText(find.byType(EditableText), '۴۸۲۱');
      await tester.pump();
      expect(completed, ['4821']);
    });

    testWidgets('the error shows under the boxes', (tester) async {
      await pump(tester, const OtpBoxes(errorText: 'کد اشتباه است', autofocus: false));
      expect(find.text('کد اشتباه است'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(AppStrings.codeFieldLabel)), findsWidgets);
    });
  });

  testWidgets('RangeDisplay: the two ends with the bar between, read out as «از … تا …»', (tester) async {
    await pump(tester, const RangeDisplay(start: 'متوسط رو به پایین', end: 'پیشرفته'));
    expect(find.bySemanticsLabel(AppStrings.rangeFromTo('متوسط رو به پایین', 'پیشرفته')), findsOneWidget);
    expect(tester.getCenter(find.text('متوسط رو به پایین')).dx, greaterThan(tester.getCenter(find.text('پیشرفته')).dx));
  });

  testWidgets('RadioCard: the selected card has a green border on soft green and reads as checked', (tester) async {
    var taps = 0;
    await pump(
      tester,
      Column(
        children: [
          RadioCard(title: 'شنبه در باشگاه استقلال', subtitle: '۲ آبان', selected: true, onTap: () {}),
          RadioCard(title: 'یکشنبه', selected: false, onTap: () => taps++),
        ],
      ),
    );
    final material = tester.widget<Material>(
      find.descendant(of: find.byType(RadioCard).first, matching: find.byType(Material)),
    );
    expect(material.color, light.primarySoft);
    expect((material.shape! as RoundedRectangleBorder).side.color, light.primary);
    expect(tester.getSemantics(find.byType(RadioCard).first).flagsCollection.isChecked, CheckedState.isTrue);
    await tester.tap(find.text('یکشنبه'));
    expect(taps, 1);
  });

  testWidgets('DashedButton: a 50dp dashed green button', (tester) async {
    var taps = 0;
    await pump(tester, DashedButton(label: 'ساخت بازی جدید', onPressed: () => taps++));
    expect(tester.getSize(find.byType(DashedButton)).height, 50);
    final paint = tester.widget<CustomPaint>(
      find.descendant(of: find.byType(DashedButton), matching: find.byType(CustomPaint)).first,
    );
    expect((paint.foregroundPainter! as DashedBorderPainter).color, light.primary);
    await tester.tap(find.byType(DashedButton));
    expect(taps, 1);
  });

  group('SkeletonBlock', () {
    testWidgets('static by default; lines are announced once as loading', (tester) async {
      await pump(tester, const SizedBox(width: 300, child: SkeletonLines()));
      expect(find.byType(SkeletonBlock), findsNWidgets(3));
      expect(find.descendant(of: find.byType(SkeletonLines), matching: find.byType(FadeTransition)), findsNothing);
      expect(tester.getSize(find.byType(SkeletonBlock).last).width, 225, reason: 'the last line is shorter');
      expect(find.bySemanticsLabel(AppStrings.loading), findsOneWidget);
    });

    testWidgets('a pulse stays still when the player asked for less motion, and fades otherwise', (tester) async {
      await pump(tester, const SkeletonBlock(pulse: true));
      expect(find.descendant(of: find.byType(SkeletonBlock), matching: find.byType(FadeTransition)), findsNothing);

      tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
      await pump(tester, const SkeletonBlock(pulse: true, key: ValueKey('moving')), reduceMotion: false);
      expect(
        find.descendant(of: find.byKey(const ValueKey('moving')), matching: find.byType(FadeTransition)),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
    });
  });

  testWidgets('MenuList: rows with a forward chevron, divided, each at least 54dp', (tester) async {
    var taps = 0;
    await pump(
      tester,
      MenuList(
        title: 'حساب',
        items: [
          MenuItem(icon: Icons.star_outline, label: 'اعتبار و امتیازهای من', onTap: () => taps++),
          MenuItem(icon: Icons.notifications_outlined, label: 'تنظیمات اعلان‌ها', onTap: () {}),
          MenuItem(icon: Icons.logout, label: AppStrings.signOut, onTap: () {}, destructive: true),
        ],
      ),
    );
    expect(find.byIcon(Icons.chevron_right_rounded), findsNWidgets(3));
    expect(find.byType(Divider), findsNWidgets(2));
    expect(tester.getSize(find.byType(InkWell).first).height, greaterThanOrEqualTo(54));
    expect(tester.widget<Text>(find.text(AppStrings.signOut)).style?.color, light.error);
    expect(tester.getSemantics(find.text('حساب')).flagsCollection.isHeader, isTrue);
    await tester.tap(find.text('اعتبار و امتیازهای من'));
    expect(taps, 1);
  });

  group('AppBottomNav', () {
    List<AppNavItem> items({int unread = 0}) => [
      const AppNavItem(icon: Icons.home_outlined, label: AppStrings.navHome),
      const AppNavItem(icon: Icons.search, label: AppStrings.navSearch),
      AppNavItem(icon: Icons.chat_bubble_outline, label: AppStrings.navChat, badgeCount: unread),
    ];

    testWidgets('right to left; the selected item is green and bold, the others navInactive', (tester) async {
      final chosen = <int>[];
      await pump(tester, AppBottomNav(items: items(), currentIndex: 0, onSelected: chosen.add));
      expect(
        tester.getCenter(find.text(AppStrings.navHome)).dx,
        greaterThan(tester.getCenter(find.text(AppStrings.navSearch)).dx),
      );
      final home = tester.widget<Text>(find.text(AppStrings.navHome)).style!;
      final search = tester.widget<Text>(find.text(AppStrings.navSearch)).style!;
      expect(home.color, light.primary);
      expect(home.fontWeight, FontWeight.w700);
      expect(search.color, light.navInactive);
      expect(tester.getSize(find.byType(InkResponse).first).height, greaterThanOrEqualTo(48));
      await tester.tap(find.text(AppStrings.navSearch));
      expect(chosen, [1]);
    });

    testWidgets('a badge on the chats item, read out with the tab', (tester) async {
      await pump(tester, AppBottomNav(items: items(unread: 3), currentIndex: 0, onSelected: (_) {}));
      expect(find.text('۳'), findsOneWidget);
      expect(find.bySemanticsLabel('${AppStrings.navChat}، ${AppStrings.unreadCount('۳')}'), findsOneWidget);
    });
  });

  testWidgets('the restyled EmptyState and ErrorState use the soft tone circles', (tester) async {
    await pump(tester, const EmptyState(icon: Icons.sports_tennis, title: 'بازی‌ای نیست', subtitle: 'هنوز چیزی نیست'));
    final circle = find.ancestor(of: find.byIcon(Icons.sports_tennis), matching: find.byType(Container)).first;
    expect(decorationOf(tester, circle).color, light.primarySoft);
    expect(tester.widget<Text>(find.text('هنوز چیزی نیست')).style?.color, light.muted);

    await pump(tester, ErrorState(onRetry: () {}));
    final errorCircle = find
        .ancestor(of: find.byIcon(Icons.error_outline_rounded), matching: find.byType(Container))
        .first;
    expect(decorationOf(tester, errorCircle).color, light.errorSoft);
  });

  testWidgets('AppSnackbar: success on ink, error on the error colour', (tester) async {
    await pump(
      tester,
      Builder(
        builder: (context) => Column(
          children: [
            TextButton(onPressed: () => AppSnackbar.success(context, 'ذخیره شد'), child: const Text('s')),
            TextButton(onPressed: () => AppSnackbar.error(context, 'ذخیره نشد'), child: const Text('e')),
          ],
        ),
      ),
    );
    await tester.tap(find.text('s'));
    await tester.pump();
    expect(tester.widget<SnackBar>(find.byType(SnackBar)).backgroundColor, AppTheme.lightScheme.inverseSurface);
    await tester.tap(find.text('e'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(tester.widget<SnackBar>(find.byType(SnackBar).last).backgroundColor, light.error);
  });

  testWidgets('every component renders in the dark theme', (tester) async {
    await pump(
      tester,
      Column(
        children: [
          AppButton(label: 'a', onPressed: () {}),
          AppButton.secondary(label: 'b', onPressed: () {}),
          const AppCard(child: Text('c')),
          const AppChip(label: 'd', tone: AppChipTone.green),
          const AvatarStack(names: ['سام', 'علی'], caption: 'e'),
          const AppBadge(count: 4),
          const SectionTitle(title: 'f'),
          AppSegmented<int>(
            segments: const [
              AppSegment(value: 1, label: 'g'),
              AppSegment(value: 2, label: 'h'),
            ],
            selected: 1,
            onChanged: (_) {},
          ),
          const NoticeBanner(tone: NoticeTone.warning, body: 'i'),
          const HeroCard(title: 'j'),
          QuickActionTile(icon: Icons.add, label: 'k', onTap: () {}),
          const SportBall(label: 'T'),
          const MetaRow(items: [MetaItem('l')]),
          const StatGrid(
            items: [StatItem(label: 'm', value: 'n')],
          ),
          const ListRow(title: 'o'),
          const StepHeader(step: 1, total: 3),
          const SearchField(),
          AppSwitchRow(title: 'p', value: true, onChanged: (_) {}),
          const RangeDisplay(start: 'q', end: 'r'),
          RadioCard(title: 's', selected: true, onTap: () {}),
          DashedButton(label: 't', onPressed: () {}),
          const SkeletonLines(),
          MenuList(
            items: [MenuItem(label: 'u', onTap: () {})],
          ),
        ],
      ),
      theme: AppTheme.dark,
    );
    expect(tester.takeException(), isNull);
    expect(Theme.of(tester.element(find.text('a'))).extension<AppPalette>(), AppPalette.dark);
  });
}
