using Microsoft.Extensions.DependencyInjection;
using Rallyto.Community.Application.Players;

namespace Rallyto.Community.Application;

public static class CommunityApplicationRegistration
{
    public static IServiceCollection AddCommunityApplicationServices(this IServiceCollection services)
    {
        services.AddScoped<PlayerContext>();
        services.AddScoped<VisibilityService>();
        services.AddScoped<ProfileAssembler>();
        services.AddScoped<Availability.AvailabilityAssembler>();
        services.AddScoped<Search.SearchCriteriaResolver>();
        services.AddScoped<Search.PartnerSearchService>();
        services.AddScoped<Search.SavedSearchAssembler>();
        services.AddScoped<Matches.MatchAssembler>();
        services.AddScoped<Matches.MatchWorkflow>();
        services.AddScoped<Matches.PostSearchService>();
        services.AddScoped<Ratings.ReputationService>();
        return services;
    }
}
