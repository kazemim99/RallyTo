using DotNetCore.CAP;
using Microsoft.Extensions.Logging;
using Rallyto.Identity.Application.Abstractions;
using Rallyto.Infrastructure.Core.Events;
using Rallyto.Infrastructure.Core.Persistence;

namespace Rallyto.Identity.Infrastructure.Persistence;

public sealed class IdentityUnitOfWork(
    IdentityDbContext dbContext,
    DomainEventDispatcher dispatcher,
    IntegrationEventBuffer integrationEvents,
    ICapPublisher capPublisher,
    ILogger<IdentityUnitOfWork> logger)
    : EfUnitOfWork<IdentityDbContext>(dbContext, dispatcher, integrationEvents, capPublisher, logger), IIdentityUnitOfWork;
