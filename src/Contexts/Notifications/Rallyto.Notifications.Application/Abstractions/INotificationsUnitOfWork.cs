using Rallyto.Core.Application.Abstractions;

namespace Rallyto.Notifications.Application.Abstractions;

/// <summary>The Notifications context's unit of work. Handlers of this context save through it and nothing else (design D12).</summary>
public interface INotificationsUnitOfWork : IUnitOfWork;
