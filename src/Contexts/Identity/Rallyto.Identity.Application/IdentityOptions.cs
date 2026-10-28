namespace Rallyto.Identity.Application;

/// <summary>Sign-in code rules; defaults are the values in spec identity-access (after AsanRezerve's OtpProtectionOptions).</summary>
public sealed class OtpOptions
{
    public const string SectionName = "Otp";
    public int CodeLength { get; set; } = 4;
    public int LifetimeSeconds { get; set; } = 300;
    public int MaxAttempts { get; set; } = 5;
    public int BlockMinutes { get; set; } = 60;
    public int ResendCooldownSeconds { get; set; } = 60;
    public int MaxSendsPerWindow { get; set; } = 3;
    public int WindowMinutes { get; set; } = 10;
    public string? SandboxCode { get; set; }

    public TimeSpan Lifetime => TimeSpan.FromSeconds(LifetimeSeconds);
    public TimeSpan Block => TimeSpan.FromMinutes(BlockMinutes);
    public TimeSpan ResendCooldown => TimeSpan.FromSeconds(ResendCooldownSeconds);
    public TimeSpan Window => TimeSpan.FromMinutes(WindowMinutes);
}

public sealed class IdentityOptions
{
    public const string SectionName = "Identity";

    /// <summary>The admin panel's account; set through user-secrets or the environment, never in the repository.</summary>
    public InitialAdminOptions InitialAdmin { get; set; } = new();
}

public sealed class InitialAdminOptions
{
    public string? Email { get; set; }
    public string? Password { get; set; }
}
