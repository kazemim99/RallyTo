using DotNetCore.CAP;
using Microsoft.Extensions.Logging;
using Rallyto.Community.Application.Abstractions;
using Rallyto.Infrastructure.Core.Events;
using Rallyto.Infrastructure.Core.Persistence;

namespace Rallyto.Community.Infrastructure.Persistence;

public sealed class CommunityUnitOfWork(
    CommunityDbContext dbContext,
    DomainEventDispatcher dispatcher,
    IntegrationEventBuffer integrationEvents,
    ICapPublisher capPublisher,
    ILogger<CommunityUnitOfWork> logger)
    : EfUnitOfWork<CommunityDbContext>(dbContext, dispatcher, integrationEvents, capPublisher, logger), ICommunityUnitOfWork;
