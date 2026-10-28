using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Rallyto.Notifications.Application;
using Rallyto.Notifications.Application.Abstractions;
using Rallyto.Notifications.Application.Delivery;
using Rallyto.Notifications.Infrastructure.Persistence;
using Rallyto.Infrastructure.Core.DependencyInjection;

namespace Rallyto.Notifications.Infrastructure;

public static class NotificationsModule
{
    public const string Schema = "notifications";

    /// <summary>CAP consumer group: each context subscribes in its own group so every context gets every event.</summary>
    public const string CapGroup = "rallyto.notifications";

    public static IServiceCollection AddNotificationsModule(this IServiceCollection services, IConfiguration configuration)
    {
        services.AddContextDbContext<NotificationsDbContext>(configuration, Schema);
        services.AddScoped<INotificationsUnitOfWork, NotificationsUnitOfWork>();
        services.AddContextApplication(typeof(NotificationsApplicationMarker).Assembly);

        services.AddScoped<INotificationRepository, NotificationRepository>();
        services.AddScoped<NotificationComposer>();
        services.AddScoped<NotificationDispatcher>();
        // The gateway is a singleton because FirebaseApp is process-wide and refuses to be created twice.
        services.AddSingleton<IPushGateway, Push.FirebasePushGateway>();
        services.AddTransient<NotificationSubscribers>();
        services.AddScoped<NotificationsMaintenance>();
        services.AddHostedService<NotificationsMaintenanceWorker>();
        return services;
    }
}
