using Rallyto.Community.Domain.Players;
using Rallyto.Core.Domain.Exceptions;
using Rallyto.Core.Domain.SharedKernel;

namespace Rallyto.Community.UnitTests;

public sealed class PlayerProfileRulesTests
{
    private static readonly DateOnly Today = new(2026, 10, 23);
    private static readonly SportProfile Tennis = new(Guid.NewGuid(), LevelTier.Intermediate, ExperienceBand.OneToThreeYears, [PlayFormat.Singles], PlayGoals.FriendlyMatch);

    private static PlayerProfile Create(DateOnly birth, string name = "علی") =>
        PlayerProfile.Create(Guid.NewGuid(), name, Gender.Male, birth, Today, 428, null, [Tennis], DateTime.UtcNow);

    [Fact]
    public void Exactly_18_today_is_allowed_one_day_short_is_not()
    {
        Create(new DateOnly(2008, 10, 22)).Should().NotBeNull(); // 1387/08/01: 18 on 1405/08/01
        var underage = () => Create(new DateOnly(2008, 10, 23)); // 1387/08/02: 18 only tomorrow
        underage.Should().Throw<BusinessRuleViolationException>().Which.ErrorCode.Should().Be("UNDER_18");
    }

    [Theory]
    [InlineData(18, AgeRange.From18To24)]
    [InlineData(24, AgeRange.From18To24)]
    [InlineData(25, AgeRange.From25To34)]
    [InlineData(35, AgeRange.From35To44)]
    [InlineData(54, AgeRange.From45To54)]
    [InlineData(70, AgeRange.From55)]
    public void Age_ranges(int age, AgeRange expected) => PlayerProfile.RangeOf(age).Should().Be(expected);

    [Theory]
    [InlineData("ع")]
    [InlineData("نام‌خیلی‌خیلی‌طولانی‌که‌بیش‌از‌سی‌نویسه‌است")]
    [InlineData("علی<script>")]
    [InlineData("علی@")]
    public void Invalid_display_names_are_rejected(string name)
    {
        var create = () => Create(new DateOnly(1990, 1, 1), name);
        create.Should().Throw<BusinessRuleViolationException>().Which.ErrorCode.Should().Be("INVALID_DISPLAY_NAME");
    }

    [Fact]
    public void Persian_name_with_zero_width_non_joiner_is_accepted()
    {
        Create(new DateOnly(1990, 1, 1), "محمد‌رضا ۲").DisplayName.Should().Be("محمد‌رضا ۲");
    }

    [Fact]
    public void Last_sport_profile_cannot_be_removed()
    {
        var profile = Create(new DateOnly(1990, 1, 1));
        var remove = () => profile.RemoveSportProfile(Tennis.SportId);
        remove.Should().Throw<InvalidAggregateStateException>().Which.ErrorCode.Should().Be("LAST_SPORT_PROFILE");
    }

    [Fact]
    public void Anonymising_forgets_personal_data()
    {
        var profile = Create(new DateOnly(1990, 1, 1));
        profile.SetPhoto("/media/avatars/x.jpg");

        profile.Anonymize();

        profile.DisplayName.Should().Be(PlayerProfile.DeletedDisplayName);
        profile.PhotoKey.Should().BeNull();
        profile.BirthDate.Should().BeNull();
        profile.Status.Should().Be(ProfileStatus.Deleted);
    }
}

public sealed class VisibilityPolicyTests
{
    private static PlayerVisibilityFacts P(Gender g, ProfileVisibility v = ProfileVisibility.Everyone, ProfileStatus s = ProfileStatus.Active) =>
        new(Guid.NewGuid(), g, v, s);

    [Fact]
    public void Everyone_sees_everyone_by_default() =>
        VisibilityPolicy.CanSee(P(Gender.Male), P(Gender.Female), false).Should().BeTrue();

    [Fact]
    public void A_block_in_either_direction_hides() =>
        VisibilityPolicy.CanSee(P(Gender.Male), P(Gender.Male), blockedEitherWay: true).Should().BeFalse();

    [Fact]
    public void Same_gender_subject_is_hidden_from_the_other_gender_only()
    {
        var restrictedWoman = P(Gender.Female, ProfileVisibility.SameGender);
        VisibilityPolicy.CanSee(P(Gender.Male), restrictedWoman, false).Should().BeFalse();
        VisibilityPolicy.CanSee(P(Gender.Female), restrictedWoman, false).Should().BeTrue();
    }

    [Fact]
    public void A_restricted_viewer_does_not_see_the_other_gender() =>
        VisibilityPolicy.CanSee(P(Gender.Female, ProfileVisibility.SameGender), P(Gender.Male), false).Should().BeFalse();

    [Theory]
    [InlineData(ProfileStatus.Hidden)]
    [InlineData(ProfileStatus.Deleted)]
    public void Inactive_profiles_are_hidden(ProfileStatus status) =>
        VisibilityPolicy.CanSee(P(Gender.Male), P(Gender.Male, s: status), false).Should().BeFalse();

    [Fact]
    public void A_player_always_sees_themselves()
    {
        var me = P(Gender.Male, ProfileVisibility.SameGender);
        VisibilityPolicy.CanSee(me, me, blockedEitherWay: true).Should().BeTrue();
    }
}

public sealed class LastActivityTests
{
    private static readonly DateTime Now = new(2026, 10, 23, 9, 0, 0, DateTimeKind.Utc);
    private static DateOnly Tehran(DateTime utc) => DateOnly.FromDateTime(utc.AddMinutes(210));

    [Theory]
    [InlineData(0, LastActiveBucket.Today)]
    [InlineData(3 * 24, LastActiveBucket.ThisWeek)]
    [InlineData(20 * 24, LastActiveBucket.ThisMonth)]
    [InlineData(60 * 24, LastActiveBucket.Earlier)]
    public void Buckets(int hoursAgo, LastActiveBucket expected) =>
        LastActivity.Bucket(Now.AddHours(-hoursAgo), Now, Tehran).Should().Be(expected);
}
