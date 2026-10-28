using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Rallyto.Core.Application.Abstractions;
using Rallyto.Identity.Application;
using Rallyto.Identity.Application.Abstractions;
using Rallyto.Identity.Infrastructure.Persistence;
using Rallyto.Identity.Infrastructure.Security;
using Rallyto.Identity.Infrastructure.Sms;
using Rallyto.Infrastructure.Core.DependencyInjection;

namespace Rallyto.Identity.Infrastructure;

public static class IdentityModule
{
    public const string Schema = "identity";
    public const string CapGroup = "rallyto.identity";

    public static IServiceCollection AddIdentityModule(this IServiceCollection services, IConfiguration configuration)
    {
        services.AddContextDbContext<IdentityDbContext>(configuration, Schema);
        services.AddScoped<IIdentityUnitOfWork, IdentityUnitOfWork>();
        services.AddContextApplication(typeof(IdentityApplicationMarker).Assembly);
        services.AddIdentityApplicationServices();

        services.Configure<OtpOptions>(configuration.GetSection(OtpOptions.SectionName));
        services.Configure<IdentityOptions>(configuration.GetSection(IdentityOptions.SectionName));
        services.AddSingleton<IPasswordHasher, Security.Pbkdf2PasswordHasher>();
        services.AddScoped<Rallyto.Infrastructure.Core.Persistence.IDataSeeder, Security.InitialAdminSeeder>();

        services.AddScoped<IAccountRepository, AccountRepository>();
        services.AddScoped<IRefreshTokenRepository, RefreshTokenRepository>();
        services.AddScoped<IPhoneVerificationRepository, PhoneVerificationRepository>();
        services.AddSingleton<ISecretHasher, SecretHasher>();
        services.AddSingleton<IOtpCodeGenerator, OtpCodeGenerator>();
        services.AddSingleton<ITokenService, TokenService>();
        services.AddSingleton<AccountStatusReader>();
        services.AddSingleton<IAccountStatusReader>(sp => sp.GetRequiredService<AccountStatusReader>());
        services.AddSingleton<IAccountStatusCache>(sp => sp.GetRequiredService<AccountStatusReader>());

        services.AddTransient<Subscribers.ProfileCreatedSubscriber>();

        if (string.Equals(configuration["Sms:Provider"], "MeliPayamak", StringComparison.OrdinalIgnoreCase))
        {
            services.Configure<MeliPayamakOptions>(configuration.GetSection(MeliPayamakOptions.SectionName));
            services.AddHttpClient<ISmsSender, MeliPayamakSmsSender>(client => client.Timeout = TimeSpan.FromSeconds(15));
        }
        else
        {
            services.AddSingleton<ISmsSender, LoggingSmsSender>();
        }

        return services;
    }
}
