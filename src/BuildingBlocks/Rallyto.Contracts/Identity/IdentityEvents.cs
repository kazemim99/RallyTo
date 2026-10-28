using Rallyto.Core.Application.Abstractions;

namespace Rallyto.Contracts.Identity;

public static class IdentityTopics
{
    public const string AccountSuspended = "rallyto.identity.account-suspended";
    public const string AccountBanned = "rallyto.identity.account-banned";
    public const string AccountReactivated = "rallyto.identity.account-reactivated";
    public const string AccountDeleted = "rallyto.identity.account-deleted";
}

public sealed record AccountSuspended(Guid UserId, DateTime SuspendedUntil, string Reason) : IntegrationEvent
{
    public override string Topic => IdentityTopics.AccountSuspended;
}

public sealed record AccountBanned(Guid UserId, string Reason) : IntegrationEvent
{
    public override string Topic => IdentityTopics.AccountBanned;
}

public sealed record AccountReactivated(Guid UserId) : IntegrationEvent
{
    public override string Topic => IdentityTopics.AccountReactivated;
}

public sealed record AccountDeleted(Guid UserId) : IntegrationEvent
{
    public override string Topic => IdentityTopics.AccountDeleted;
}
