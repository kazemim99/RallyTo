using Rallyto.Core.Application.Abstractions;

namespace Rallyto.Contracts.Admin;

public static class AdminTopics
{
    public const string ActionRecorded = "rallyto.admin.action-recorded";
}

/// <summary>
/// Published by every admin command in every context; the admin audit log (spec trust-safety) is built from these.
/// </summary>
public sealed record AdminActionRecorded(
    Guid AdminId,
    string Action,
    string TargetType,
    string TargetId,
    Guid? TargetUserId,
    string? Reason) : IntegrationEvent
{
    public override string Topic => AdminTopics.ActionRecorded;
}
