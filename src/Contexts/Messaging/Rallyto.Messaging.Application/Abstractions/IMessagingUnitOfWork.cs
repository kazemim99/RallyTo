using Rallyto.Core.Application.Abstractions;

namespace Rallyto.Messaging.Application.Abstractions;

/// <summary>The Messaging context's unit of work. Handlers of this context save through it and nothing else (design D12).</summary>
public interface IMessagingUnitOfWork : IUnitOfWork;
