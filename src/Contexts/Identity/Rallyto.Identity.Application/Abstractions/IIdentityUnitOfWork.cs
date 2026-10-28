using Rallyto.Core.Application.Abstractions;

namespace Rallyto.Identity.Application.Abstractions;

/// <summary>The Identity context's unit of work. Handlers of this context save through it and nothing else (design D12).</summary>
public interface IIdentityUnitOfWork : IUnitOfWork;
