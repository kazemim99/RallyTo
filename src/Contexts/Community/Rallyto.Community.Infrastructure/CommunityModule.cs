using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Rallyto.Community.Application;
using Rallyto.Community.Application.Abstractions;
using Rallyto.Community.Infrastructure.Persistence;
using Rallyto.Community.Infrastructure.Players;
using Rallyto.Infrastructure.Core.DependencyInjection;

namespace Rallyto.Community.Infrastructure;

public static class CommunityModule
{
    public const string Schema = "community";

    /// <summary>CAP consumer group: each context subscribes in its own group so every context gets every event.</summary>
    public const string CapGroup = "rallyto.community";

    public static IServiceCollection AddCommunityModule(this IServiceCollection services, IConfiguration configuration)
    {
        services.AddContextDbContext<CommunityDbContext>(configuration, Schema);
        services.AddScoped<ICommunityUnitOfWork, CommunityUnitOfWork>();
        services.AddContextApplication(typeof(CommunityApplicationMarker).Assembly);
        services.AddCommunityApplicationServices();

        services.AddScoped<IPlayerProfileRepository, PlayerProfileRepository>();
        services.AddScoped<IBlockRepository, BlockRepository>();
        services.AddScoped<IAvailabilityRepository, AvailabilityRepository>();
        services.AddScoped<Application.Search.ISavedSearchRepository, SavedSearchRepository>();
        services.AddScoped<Application.Search.IPartnerSearchReader, Search.PartnerSearchReader>();
        services.AddSingleton(configuration.GetSection("Search:Ranking").Get<Domain.Search.RankingWeights>() ?? new Domain.Search.RankingWeights());
        services.AddScoped<Application.Matches.IMatchRepository, MatchRepository>();
        services.AddScoped<Application.Ratings.IRatingRepository, RatingRepository>();
        services.AddScoped<Application.Ratings.IReputationReader, ReputationReader>();
        services.AddScoped<Application.Safety.ISafetyRepository, SafetyRepository>();
        services.AddScoped<Application.Safety.IUsageStatsReader, UsageStatsReader>();
        services.AddTransient<AdminAuditSubscriber>();
        services.AddSingleton(new Application.Matches.PublicLinks(configuration["PublicBaseUrl"] ?? "http://localhost:5000"));
        services.AddScoped<Jobs.CommunityMaintenance>();
        services.AddHostedService<Jobs.CommunityMaintenanceWorker>();
        services.AddTransient<Jobs.VenueHiddenSubscriber>();
        services.AddScoped<IAvatarProcessor, AvatarProcessor>();
        services.AddMemoryCache();
        services.AddSingleton<PlayerActivityTracker>();
        services.AddTransient<AccountStatusSubscriber>();
        return services;
    }
}
