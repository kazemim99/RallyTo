using DotNetCore.CAP;
using Microsoft.Extensions.Logging;
using Rallyto.Notifications.Application.Abstractions;
using Rallyto.Infrastructure.Core.Events;
using Rallyto.Infrastructure.Core.Persistence;

namespace Rallyto.Notifications.Infrastructure.Persistence;

public sealed class NotificationsUnitOfWork(
    NotificationsDbContext dbContext,
    DomainEventDispatcher dispatcher,
    IntegrationEventBuffer integrationEvents,
    ICapPublisher capPublisher,
    ILogger<NotificationsUnitOfWork> logger)
    : EfUnitOfWork<NotificationsDbContext>(dbContext, dispatcher, integrationEvents, capPublisher, logger), INotificationsUnitOfWork;
