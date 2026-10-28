using System.Collections.Concurrent;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;
using Rallyto.Core.Application.Abstractions;

namespace Rallyto.Host.Composition;

/// <summary>
/// The single realtime hub (design D8). Clients only listen; every write goes through the REST API.
/// Each connection joins the group <c>user_{id}</c>.
/// </summary>
[Authorize]
public sealed class RealtimeHub(ConnectionRegistry registry) : Hub
{
    public const string Path = "/hubs/realtime";

    public static string UserGroup(Guid userId) => $"user_{userId}";

    public override async Task OnConnectedAsync()
    {
        if (TryGetUserId(out var userId))
        {
            registry.Add(userId, Context);
            await Groups.AddToGroupAsync(Context.ConnectionId, UserGroup(userId));
        }

        await base.OnConnectedAsync();
    }

    public override async Task OnDisconnectedAsync(Exception? exception)
    {
        if (TryGetUserId(out var userId))
            registry.Remove(userId, Context.ConnectionId);
        await base.OnDisconnectedAsync(exception);
    }

    private bool TryGetUserId(out Guid userId) => Guid.TryParse(Context.UserIdentifier, out userId);
}

/// <summary>In-process registry of live connections per user: presence for chat, and forced disconnects on suspension or ban.</summary>
public sealed class ConnectionRegistry : IUserPresence
{
    private readonly ConcurrentDictionary<Guid, ConcurrentDictionary<string, HubCallerContext>> _connections = new();

    public void Add(Guid userId, HubCallerContext context) =>
        _connections.GetOrAdd(userId, _ => new ConcurrentDictionary<string, HubCallerContext>())[context.ConnectionId] = context;

    public void Remove(Guid userId, string connectionId)
    {
        if (_connections.TryGetValue(userId, out var connections))
        {
            connections.TryRemove(connectionId, out _);
            if (connections.IsEmpty)
                _connections.TryRemove(userId, out _);
        }
    }

    public bool IsOnline(Guid userId) => _connections.TryGetValue(userId, out var connections) && !connections.IsEmpty;

    public void AbortAll(Guid userId)
    {
        if (_connections.TryRemove(userId, out var connections))
        {
            foreach (var context in connections.Values)
                context.Abort();
        }
    }
}

public sealed class SignalRRealtimePublisher(IHubContext<RealtimeHub> hub, ConnectionRegistry registry) : IRealtimePublisher
{
    public Task PublishToUsersAsync(IReadOnlyCollection<Guid> userIds, string eventName, object payload, CancellationToken cancellationToken = default) =>
        userIds.Count == 0
            ? Task.CompletedTask
            : hub.Clients.Groups(userIds.Select(RealtimeHub.UserGroup).ToList()).SendAsync(eventName, payload, cancellationToken);

    public Task DisconnectUserAsync(Guid userId, CancellationToken cancellationToken = default)
    {
        registry.AbortAll(userId);
        return Task.CompletedTask;
    }
}
