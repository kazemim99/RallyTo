using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Rallyto.Messaging.Application;
using Rallyto.Messaging.Application.Abstractions;
using Rallyto.Messaging.Infrastructure.Persistence;
using Rallyto.Infrastructure.Core.DependencyInjection;

namespace Rallyto.Messaging.Infrastructure;

public static class MessagingModule
{
    public const string Schema = "messaging";

    /// <summary>CAP consumer group: each context subscribes in its own group so every context gets every event.</summary>
    public const string CapGroup = "rallyto.messaging";

    public static IServiceCollection AddMessagingModule(this IServiceCollection services, IConfiguration configuration)
    {
        services.AddContextDbContext<MessagingDbContext>(configuration, Schema);
        services.AddScoped<IMessagingUnitOfWork, MessagingUnitOfWork>();
        services.AddContextApplication(typeof(MessagingApplicationMarker).Assembly);
        services.AddMessagingApplicationServices();

        services.AddScoped<IConversationRepository, ConversationRepository>();
        services.AddScoped<IMessageRepository, MessageRepository>();
        services.AddTransient<MatchEventsSubscriber>();
        services.AddTransient<AccountStatusSubscriber>();
        services.AddTransient<ModerationSubscriber>();
        return services;
    }
}
