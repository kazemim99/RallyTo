using Microsoft.Extensions.DependencyInjection;
using Rallyto.Messaging.Application.Conversations;

namespace Rallyto.Messaging.Application;

public static class MessagingApplicationRegistration
{
    public static IServiceCollection AddMessagingApplicationServices(this IServiceCollection services)
    {
        services.AddScoped<ChatSession>();
        services.AddScoped<ConversationAssembler>();
        services.AddScoped<ConversationLists>();
        services.AddScoped<MatchConversationSync>();
        return services;
    }
}
