using Microsoft.Extensions.DependencyInjection;
using Rallyto.Catalog.Application.Sports;
using Rallyto.Catalog.Application.Venues;

namespace Rallyto.Catalog.Application;

public static class CatalogApplicationRegistration
{
    public static IServiceCollection AddCatalogApplicationServices(this IServiceCollection services)
    {
        services.AddScoped<CatalogAdminSession>();
        services.AddScoped<VenueAssembler>();
        return services;
    }
}
