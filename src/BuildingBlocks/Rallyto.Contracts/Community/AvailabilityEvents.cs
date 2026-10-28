using Rallyto.Core.Application.Abstractions;

namespace Rallyto.Contracts.Community;

public static class AvailabilityTopics
{
    public const string ReconfirmationDue = "rallyto.community.availability-reconfirmation-due";
    public const string AutoPaused = "rallyto.community.availability-auto-paused";
    public const string SavedSearchMatched = "rallyto.community.saved-search-matched";
}

/// <summary>Day 27 without confirmation: ask the player whether they are still available.</summary>
public sealed record AvailabilityReconfirmationDue(Guid UserId, Guid AvailabilityId) : IntegrationEvent
{
    public override string Topic => AvailabilityTopics.ReconfirmationDue;
}

/// <summary>Day 30 without confirmation: the window was paused.</summary>
public sealed record AvailabilityAutoPaused(Guid UserId, Guid AvailabilityId) : IntegrationEvent
{
    public override string Topic => AvailabilityTopics.AutoPaused;
}

/// <summary>New matches for a saved search (one alert, or a digest of several).</summary>
public sealed record SavedSearchMatched(Guid UserId, Guid SavedSearchId, string SearchName, int MatchCount) : IntegrationEvent
{
    public override string Topic => AvailabilityTopics.SavedSearchMatched;
}
