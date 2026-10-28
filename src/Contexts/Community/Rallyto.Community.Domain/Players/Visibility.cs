using Rallyto.Core.Domain.Base;
using Rallyto.Core.Domain.Exceptions;

namespace Rallyto.Community.Domain.Players;

/// <summary>One player blocking another. Its effect is mutual: neither sees the other (spec trust-safety › Block a player).</summary>
public sealed class Block : Entity<Guid>
{
    private Block() { }

    public Guid BlockerId { get; private set; }
    public Guid BlockedId { get; private set; }
    public DateTime BlockedAt { get; private set; }

    public static Block Create(Guid blockerId, Guid blockedId, DateTime now)
    {
        if (blockerId == blockedId)
            throw new BusinessRuleViolationException("CANNOT_BLOCK_SELF", "نمی‌توانید خودتان را مسدود کنید.");
        return new Block { Id = Guid.NewGuid(), BlockerId = blockerId, BlockedId = blockedId, BlockedAt = now };
    }
}

/// <summary>The facts about one player that visibility depends on.</summary>
public sealed record PlayerVisibilityFacts(Guid UserId, Gender Gender, ProfileVisibility Visibility, ProfileStatus Status);

/// <summary>
/// The single rule for who may see or interact with whom (design D11). Every read path that exposes a player —
/// profiles, search, posts, invitations, chat — goes through it.
/// </summary>
public static class VisibilityPolicy
{
    /// <param name="blockedEitherWay">Whether either player has blocked the other.</param>
    public static bool CanSee(PlayerVisibilityFacts viewer, PlayerVisibilityFacts subject, bool blockedEitherWay)
    {
        if (viewer.UserId == subject.UserId)
            return true;
        if (blockedEitherWay || subject.Status != ProfileStatus.Active || viewer.Status != ProfileStatus.Active)
            return false;
        // Same-gender visibility works both ways: a restricted player is shown only to, and only sees, the same gender.
        if (subject.Visibility == ProfileVisibility.SameGender && viewer.Gender != subject.Gender)
            return false;
        if (viewer.Visibility == ProfileVisibility.SameGender && viewer.Gender != subject.Gender)
            return false;
        return true;
    }

    public static PlayerVisibilityFacts FactsOf(PlayerProfile profile) => new(profile.Id, profile.Gender, profile.Visibility, profile.Status);
}

/// <summary>A coarse "last seen" bucket; exact timestamps are never shown to other players.</summary>
public enum LastActiveBucket
{
    Today = 1,
    ThisWeek = 2,
    ThisMonth = 3,
    Earlier = 4,
}

public static class LastActivity
{
    public static LastActiveBucket Bucket(DateTime lastActiveUtc, DateTime nowUtc, Func<DateTime, DateOnly> tehranDate)
    {
        if (tehranDate(lastActiveUtc) == tehranDate(nowUtc))
            return LastActiveBucket.Today;
        var age = nowUtc - lastActiveUtc;
        return age <= TimeSpan.FromDays(7) ? LastActiveBucket.ThisWeek
            : age <= TimeSpan.FromDays(30) ? LastActiveBucket.ThisMonth
            : LastActiveBucket.Earlier;
    }
}
