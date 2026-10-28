namespace Rallyto.Host.Composition;

/// <summary>
/// Refuses to start in Production with development-only settings (spec identity-access › Production configuration guard).
/// Runs before anything else is registered, like AsanRezerve's guard.
/// </summary>
public static class ProductionConfigurationGuard
{
    public const string SandboxCodeVariable = "OTP_SANDBOX_CODE";
    private const int MinimumJwtKeyLength = 32;

    public static void ThrowIfInvalid(IConfiguration configuration, IHostEnvironment environment)
    {
        var problems = FindProblems(configuration, environment, Environment.GetEnvironmentVariable(SandboxCodeVariable));
        if (problems.Count > 0)
            throw new InvalidOperationException("Invalid production configuration: " + string.Join("; ", problems));
    }

    public static IReadOnlyList<string> FindProblems(IConfiguration configuration, IHostEnvironment environment, string? sandboxCode)
    {
        if (!environment.IsProduction())
            return [];

        var problems = new List<string>();
        if (!string.IsNullOrWhiteSpace(sandboxCode) || !string.IsNullOrWhiteSpace(configuration["Otp:SandboxCode"]))
            problems.Add($"{SandboxCodeVariable} / Otp:SandboxCode must not be set in Production");

        var jwtKey = configuration["Jwt:SecretKey"] ?? string.Empty;
        if (jwtKey.Length < MinimumJwtKeyLength || jwtKey.Contains("CHANGE_ME", StringComparison.OrdinalIgnoreCase))
            problems.Add($"Jwt:SecretKey must be a real secret of at least {MinimumJwtKeyLength} characters");

        var smsProvider = configuration["Sms:Provider"] ?? string.Empty;
        if (!string.Equals(smsProvider, "MeliPayamak", StringComparison.OrdinalIgnoreCase))
            problems.Add("Sms:Provider must be MeliPayamak in Production (not a fake or sandbox sender)");
        else if (string.IsNullOrWhiteSpace(configuration["MeliPayamak:UserName"]) || string.IsNullOrWhiteSpace(configuration["MeliPayamak:ApiKey"])
                 || !int.TryParse(configuration["MeliPayamak:OtpBodyId"], out var bodyId) || bodyId <= 0)
            problems.Add("MeliPayamak:UserName, ApiKey and OtpBodyId must be set in Production, or no sign-in code is ever sent");

        if (string.IsNullOrWhiteSpace(configuration["Identity:InitialAdmin:Email"]) || (configuration["Identity:InitialAdmin:Password"]?.Length ?? 0) < 10)
            problems.Add("Identity:InitialAdmin:Email and a Password of at least 10 characters must be set in Production");

        // Share links and the /m/{token} page are built from it.
        if (!Uri.TryCreate(configuration["PublicBaseUrl"], UriKind.Absolute, out var baseUrl) || baseUrl.Scheme != Uri.UriSchemeHttps || baseUrl.IsLoopback)
            problems.Add("PublicBaseUrl must be the public https address of the site");

        // Without credentials the push gateway skips every push without failing.
        if (string.IsNullOrWhiteSpace(configuration["Notifications:Firebase:CredentialsJson"]) && string.IsNullOrWhiteSpace(configuration["Notifications:Firebase:CredentialsPath"]))
            problems.Add("Notifications:Firebase:CredentialsJson or CredentialsPath must be set in Production");

        return problems;
    }
}
