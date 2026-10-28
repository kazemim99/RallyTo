import '../../../core/constants/app_strings.dart';
import '../../../core/utils/display_join.dart';
import '../../../core/utils/persian_digits.dart';
import '../../../core/utils/tehran_time.dart';
import '../../availability/domain/entities/availability_window.dart';
import '../../availability/presentation/availability_labels.dart';
import '../../matches/presentation/match_labels.dart';
import 'bloc/home_cubit.dart';

/// Persian labels for home.
class HomeLabels {
  HomeLabels._();

  /// The greeting for the time of day on Tehran's clock: morning from 05:00, noon from 12:00, afternoon from 15:00,
  /// night from 19:00.
  static String greeting(DateTime now) {
    final hour = tehranWallClock(now).hour;
    if (hour >= 5 && hour < 12) return AppStrings.greetingMorning;
    if (hour >= 12 && hour < 15) return AppStrings.greetingNoon;
    if (hour >= 15 && hour < 19) return AppStrings.greetingAfternoon;
    return AppStrings.greetingNight;
  }

  /// «سارا، آماده‌ای بازی کنیم؟», or the question alone without a name.
  static String headline(String? name) => name == null ? AppStrings.homeReady : AppStrings.homeReadyNamed(name);

  /// The pending action's title: «دعوت به بازی از سارا», «۲ درخواست پیوستن»…
  static String taskTitle(HomeTask task) => switch (task.kind) {
    HomeTaskKind.invitation => AppStrings.pendingInvitation(task.match.host.displayName),
    HomeTaskKind.requests => AppStrings.pendingRequests(PersianDigits.fromInt(task.match.pendingRequests.length)),
    HomeTaskKind.attendance => AppStrings.pendingAttendance,
    HomeTaskKind.rating => AppStrings.pendingRating,
  };

  /// The game it is about: «تنیس • انفرادی • شنبه ۲ آبان ۱۴۰۵ • ۱۹:۰۰ تا ۲۰:۳۰».
  static String taskSubtitle(HomeTask task) =>
      [MatchLabels.title(task.match), MatchLabels.when(task.match)].joinDisplay();

  /// The reminder's question: the days of a single weekly window, else a general one.
  static String reconfirmTitle(List<AvailabilityWindow> windows) => windows.length == 1
      ? AppStrings.reconfirmDays(windows.single.weekdays.map(AvailabilityLabels.weekday).join('، '))
      : AppStrings.reconfirmTitle;

  /// When they pause themselves: «بازهٔ زمانی شما ۳۰ آبان ۱۴۰۵ متوقف می‌شود.».
  static String reconfirmBody(List<AvailabilityWindow> windows) => AvailabilityLabels.pauseNotice(windows);
}
