using Microsoft.Extensions.DependencyInjection;
using Rallyto.Identity.Application.Admin;
using Rallyto.Identity.Application.SignIn;

namespace Rallyto.Identity.Application;

public static class IdentityApplicationRegistration
{
    /// <summary>Application services that handlers share (handlers themselves are registered by MediatR).</summary>
    public static IServiceCollection AddIdentityApplicationServices(this IServiceCollection services)
    {
        services.AddScoped<OtpService>();
        services.AddScoped<TokenIssuer>();
        services.AddScoped<AccountAdministration>();
        return services;
    }
}
