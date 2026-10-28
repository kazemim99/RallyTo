using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Rallyto.Catalog.Application;
using Rallyto.Catalog.Application.Abstractions;
using Rallyto.Catalog.Infrastructure.Persistence;
using Rallyto.Infrastructure.Core.DependencyInjection;
using Rallyto.Infrastructure.Core.Persistence;

namespace Rallyto.Catalog.Infrastructure;

public static class CatalogModule
{
    public const string Schema = "catalog";

    public static IServiceCollection AddCatalogModule(this IServiceCollection services, IConfiguration configuration)
    {
        services.AddContextDbContext<CatalogDbContext>(configuration, Schema);
        services.AddScoped<ICatalogUnitOfWork, CatalogUnitOfWork>();
        services.AddContextApplication(typeof(CatalogApplicationMarker).Assembly);
        services.AddCatalogApplicationServices();

        services.AddScoped<ISportRepository, SportRepository>();
        services.AddScoped<ILocationRepository, LocationRepository>();
        services.AddScoped<IVenueRepository, VenueRepository>();
        services.AddScoped<IVenueCandidateRepository, VenueCandidateRepository>();
        services.AddScoped<IDataSeeder, CatalogSeeder>();
        return services;
    }
}
