namespace Rallyto.Core.Application.Abstractions;

public enum AccountStatusKind
{
    Unknown = 0,
    Active = 1,
    Suspended = 2,
    Banned = 3,
    Deleted = 4,
}

/// <summary>
/// Current status of an account, owned by Identity and read by every request (cached, evicted when the status
/// changes). Implemented in Identity's infrastructure.
/// </summary>
public interface IAccountStatusReader
{
    Task<AccountStatusKind> GetStatusAsync(Guid userId, CancellationToken cancellationToken = default);
}
