using Rallyto.Core.Domain.Exceptions;
using Rallyto.Notifications.Application.Abstractions;
using Rallyto.Notifications.Application.Catalog;
using Rallyto.Notifications.Domain;

namespace Rallyto.Notifications.UnitTests;

public sealed class PushRulesTests
{
    private static readonly Guid User = Guid.NewGuid();

    [Theory]
    [InlineData(23 * 60, true)]
    [InlineData(1 * 60, true)]
    [InlineData(7 * 60 + 59, true)]
    [InlineData(8 * 60, false)]
    [InlineData(22 * 60 + 59, false)]
    public void Default_quiet_hours_span_midnight(int localMinute, bool quiet) =>
        NotificationPreferences.DefaultsFor(User).IsQuiet(localMinute).Should().Be(quiet);

    [Fact]
    public void Quiet_hours_can_be_turned_off()
    {
        var preferences = NotificationPreferences.DefaultsFor(User);
        preferences.Update(true, true, true, true, quietHoursEnabled: false, 23 * 60, 8 * 60);

        preferences.IsQuiet(60).Should().BeFalse();
    }

    [Fact]
    public void Quiet_hours_move_in_half_hours_and_cannot_be_empty()
    {
        var preferences = NotificationPreferences.DefaultsFor(User);

        var odd = () => preferences.Update(true, true, true, true, true, 23 * 60 + 10, 8 * 60);
        var empty = () => preferences.Update(true, true, true, true, true, 8 * 60, 8 * 60);

        odd.Should().Throw<BusinessRuleViolationException>().Which.ErrorCode.Should().Be("INVALID_QUIET_HOURS");
        empty.Should().Throw<BusinessRuleViolationException>();
    }

    [Fact]
    public void A_switched_off_category_is_not_pushed_but_account_notices_always_are()
    {
        var preferences = NotificationPreferences.DefaultsFor(User);
        preferences.Update(false, false, false, false, false, 23 * 60, 8 * 60);

        PushPolicy.ShouldPush(NotificationCategory.SavedSearches, false, preferences, 12 * 60).Should().BeFalse();
        PushPolicy.ShouldPush(NotificationCategory.Account, false, preferences, 12 * 60).Should().BeTrue();
    }

    [Fact]
    public void Reminders_and_imminent_cancellations_ignore_quiet_hours()
    {
        var preferences = NotificationPreferences.DefaultsFor(User);

        PushPolicy.ShouldPush(NotificationCategory.SavedSearches, NotificationEventCatalog.SavedSearchMatched.QuietExempt, preferences, 60).Should().BeFalse();
        PushPolicy.ShouldPush(NotificationCategory.Matches, NotificationEventCatalog.MatchReminder.QuietExempt, preferences, 60).Should().BeTrue();
        PushPolicy.ShouldPush(NotificationCategory.Matches, NotificationEventCatalog.MatchCancelledSoon.QuietExempt, preferences, 23 * 60 + 30).Should().BeTrue();
    }

    [Fact]
    public void Reminder_text_uses_persian_digits_and_tehran_time()
    {
        var match = new MatchSummary(Guid.NewGuid(), "تنیس", "مجموعه تنیس استقلال", new DateTime(2026, 10, 24, 15, 30, 0, DateTimeKind.Utc), Guid.NewGuid(), []);

        NotificationEventCatalog.Reminder(match, new DateTime(2026, 10, 24, 13, 30, 0, DateTimeKind.Utc))
            .Should().Be("بازی تنیس شما امروز ساعت ۱۹:۰۰ در مجموعه تنیس استقلال");
    }

    [Fact]
    public void A_device_token_moves_to_the_last_account()
    {
        var token = DeviceToken.Register(User, "abc", "android", DateTime.UtcNow);
        token.Revoke("signed out", DateTime.UtcNow);
        var other = Guid.NewGuid();

        token.AssignTo(other, "ios", DateTime.UtcNow);

        token.UserId.Should().Be(other);
        token.IsActive.Should().BeTrue();
        token.Platform.Should().Be("ios");
    }
}
