using Rallyto.Core.Application.Abstractions;

namespace Rallyto.Community.Application.Abstractions;

/// <summary>The Community context's unit of work. Handlers of this context save through it and nothing else (design D12).</summary>
public interface ICommunityUnitOfWork : IUnitOfWork;
