using Rallyto.Host.Composition;
using Rallyto.Infrastructure.Web.Api;
using Rallyto.Infrastructure.Web.Observability;

var builder = WebApplication.CreateBuilder(args);

ProductionConfigurationGuard.ThrowIfInvalid(builder.Configuration, builder.Environment);
builder.Logging.AddRallytoLogging(builder.Configuration);
builder.Services.AddRallytoHost(builder.Configuration, builder.Environment);

var app = builder.Build();

app.UseMiddleware<RequestTelemetryMiddleware>();
if (!app.Environment.IsProduction())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseMiddleware<ApiResponseMiddleware>();
app.UseMiddleware<ExceptionHandlingMiddleware>();
app.UseRallytoMedia(app.Configuration);
app.UseCors(HostRegistration.CorsPolicy);
app.UseRouting();
app.UseAuthentication();
app.UseRallytoAccountEnforcement();
app.UseMiddleware<ActivityTrackingMiddleware>();
app.UseAuthorization();
app.UseRateLimiter();

app.MapRallytoHealthChecks();
app.MapControllers();
app.MapHub<RealtimeHub>(RealtimeHub.Path);

await app.MigrateRallytoDatabasesAsync();
await app.RunAsync();

/// <summary>Entry point type, public for <c>WebApplicationFactory</c> in the integration tests.</summary>
public partial class Program;
