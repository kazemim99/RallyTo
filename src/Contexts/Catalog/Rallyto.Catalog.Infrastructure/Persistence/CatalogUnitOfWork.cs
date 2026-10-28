using DotNetCore.CAP;
using Microsoft.Extensions.Logging;
using Rallyto.Catalog.Application.Abstractions;
using Rallyto.Infrastructure.Core.Events;
using Rallyto.Infrastructure.Core.Persistence;

namespace Rallyto.Catalog.Infrastructure.Persistence;

public sealed class CatalogUnitOfWork(
    CatalogDbContext dbContext,
    DomainEventDispatcher dispatcher,
    IntegrationEventBuffer integrationEvents,
    ICapPublisher capPublisher,
    ILogger<CatalogUnitOfWork> logger)
    : EfUnitOfWork<CatalogDbContext>(dbContext, dispatcher, integrationEvents, capPublisher, logger), ICatalogUnitOfWork;
