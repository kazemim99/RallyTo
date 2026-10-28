using DotNetCore.CAP;
using Microsoft.Extensions.Logging;
using Rallyto.Messaging.Application.Abstractions;
using Rallyto.Infrastructure.Core.Events;
using Rallyto.Infrastructure.Core.Persistence;

namespace Rallyto.Messaging.Infrastructure.Persistence;

public sealed class MessagingUnitOfWork(
    MessagingDbContext dbContext,
    DomainEventDispatcher dispatcher,
    IntegrationEventBuffer integrationEvents,
    ICapPublisher capPublisher,
    ILogger<MessagingUnitOfWork> logger)
    : EfUnitOfWork<MessagingDbContext>(dbContext, dispatcher, integrationEvents, capPublisher, logger), IMessagingUnitOfWork;
