using Rallyto.Core.Application.Abstractions;

namespace Rallyto.Contracts.Community;

public static class CommunityTopics
{
    public const string ProfileCreated = "rallyto.community.profile-created";
    public const string GenderCorrected = "rallyto.community.gender-corrected";
}

/// <summary>A player finished onboarding; Identity marks the account's profile as completed.</summary>
public sealed record ProfileCreated(Guid UserId) : IntegrationEvent
{
    public override string Topic => CommunityTopics.ProfileCreated;
}

/// <summary>An admin corrected a player's gender; the player is notified.</summary>
public sealed record GenderCorrected(Guid UserId, string Reason) : IntegrationEvent
{
    public override string Topic => CommunityTopics.GenderCorrected;
}
