namespace Rallyto.Core.Application.Abstractions;

/// <summary>
/// Whether a user currently has a live realtime connection. Chat uses it to decide between a realtime
/// delivery and a push notification (design D8). Implemented by the host's connection registry.
/// </summary>
public interface IUserPresence
{
    bool IsOnline(Guid userId);
}
