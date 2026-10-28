using Rallyto.Core.Application.Abstractions;

namespace Rallyto.Catalog.Application.Abstractions;

/// <summary>The Catalog context's unit of work. Handlers of this context save through it and nothing else (design D12).</summary>
public interface ICatalogUnitOfWork : IUnitOfWork;
