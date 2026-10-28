using Rallyto.Community.Domain.Players;
using Rallyto.Core.Domain.SharedKernel;

namespace Rallyto.Community.Application.Players;

public sealed record SportProfileView(
    Guid SportId,
    string SportCode,
    LevelTier Level,
    string LevelName,
    string? LevelDescription,
    ExperienceBand Experience,
    IReadOnlyList<PlayFormat> Formats,
    IReadOnlyList<PlayGoals> Goals);

public sealed record NamedRef(Guid Id, string Name);

public sealed record CityRef(int Id, string Name);

/// <summary>What another player sees (spec player-profile › Viewing another player's profile). No phone, no birth date.</summary>
public sealed record PlayerProfileView(
    Guid UserId,
    string DisplayName,
    string? PhotoUrl,
    Gender Gender,
    string AgeRange,
    CityRef City,
    string? Bio,
    IReadOnlyList<SportProfileView> Sports,
    IReadOnlyList<NamedRef> HomeVenues,
    string MemberSince,
    LastActiveBucket LastActive,
    Ratings.ReputationView Reputation);

/// <summary>The owner's (and an admin's) view, with birth date and visibility.</summary>
public sealed record MyProfileView(
    Guid UserId,
    string DisplayName,
    string? PhotoUrl,
    Gender Gender,
    string? BirthDate,
    string AgeRange,
    CityRef City,
    string? Bio,
    ProfileVisibility Visibility,
    ProfileStatus Status,
    IReadOnlyList<SportProfileView> Sports,
    IReadOnlyList<NamedRef> HomeVenues,
    Ratings.ReputationView Reputation);

public sealed record BlockedPlayerView(Guid UserId, string DisplayName, DateTime BlockedAt);

public sealed record SportProfileInput(Guid SportId, LevelTier Level, ExperienceBand Experience, IReadOnlyList<PlayFormat> Formats, IReadOnlyList<PlayGoals> Goals);

public static class AgeRangeText
{
    public static string Of(AgeRange range) => range switch
    {
        AgeRange.From18To24 => "18-24",
        AgeRange.From25To34 => "25-34",
        AgeRange.From35To44 => "35-44",
        AgeRange.From45To54 => "45-54",
        _ => "55+",
    };
}
