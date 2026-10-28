using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.FileProviders;
using Microsoft.Extensions.Hosting;
using Rallyto.Host.Composition;

namespace Rallyto.Host.IntegrationTests.Identity;

/// <summary>spec identity-access › Production configuration guard.</summary>
public sealed class ProductionGuardTests
{
    private static readonly Dictionary<string, string?> ValidProduction = new()
    {
        ["Jwt:SecretKey"] = "a-real-production-secret-that-is-long-enough-0123456789",
        ["Sms:Provider"] = "MeliPayamak",
        ["MeliPayamak:UserName"] = "rallyto",
        ["MeliPayamak:ApiKey"] = "key",
        ["MeliPayamak:OtpBodyId"] = "12345",
        ["PublicBaseUrl"] = "https://rallyto.ir",
        ["Identity:InitialAdmin:Email"] = "admin@rallyto.ir",
        ["Identity:InitialAdmin:Password"] = "a-long-admin-password",
        ["Notifications:Firebase:CredentialsPath"] = "/run/secrets/firebase.json",
    };

    [Fact]
    public void Sandbox_code_in_production_is_refused()
    {
        var problems = ProductionConfigurationGuard.FindProblems(Config(ValidProduction), new Env("Production"), sandboxCode: "1234");

        problems.Should().ContainSingle(p => p.Contains("OTP_SANDBOX_CODE"));
    }

    [Fact]
    public void Placeholder_jwt_key_and_fake_sms_in_production_are_refused()
    {
        var problems = ProductionConfigurationGuard.FindProblems(
            Config(new(ValidProduction) { ["Jwt:SecretKey"] = "CHANGE_ME_TO_A_LONG_RANDOM_SECRET_OF_32_CHARS_OR_MORE", ["Sms:Provider"] = "Fake" }),
            new Env("Production"), sandboxCode: null);

        problems.Should().HaveCount(2);
    }

    [Fact]
    public void Valid_production_configuration_passes()
    {
        ProductionConfigurationGuard.FindProblems(Config(ValidProduction), new Env("Production"), null).Should().BeEmpty();
    }

    [Theory]
    [InlineData("http://localhost:5000")]
    [InlineData("http://rallyto.ir")]
    [InlineData("")]
    public void Share_links_need_a_public_https_address(string baseUrl)
    {
        var settings = new Dictionary<string, string?>(ValidProduction) { ["PublicBaseUrl"] = baseUrl };

        ProductionConfigurationGuard.FindProblems(Config(settings), new Env("Production"), null).Should().ContainSingle(p => p.Contains("PublicBaseUrl"));
    }

    [Fact]
    public void Sms_needs_its_credentials()
    {
        var settings = new Dictionary<string, string?>(ValidProduction) { ["MeliPayamak:OtpBodyId"] = null };

        ProductionConfigurationGuard.FindProblems(Config(settings), new Env("Production"), null).Should().ContainSingle(p => p.Contains("MeliPayamak"));
    }

    [Fact]
    public void The_admin_panel_needs_its_account()
    {
        var settings = new Dictionary<string, string?>(ValidProduction) { ["Identity:InitialAdmin:Password"] = "short" };

        ProductionConfigurationGuard.FindProblems(Config(settings), new Env("Production"), null).Should().ContainSingle(p => p.Contains("InitialAdmin"));
    }

    [Fact]
    public void Push_needs_firebase_credentials()
    {
        var settings = new Dictionary<string, string?>(ValidProduction) { ["Notifications:Firebase:CredentialsPath"] = null };

        ProductionConfigurationGuard.FindProblems(Config(settings), new Env("Production"), null).Should().ContainSingle(p => p.Contains("Firebase"));
    }

    [Fact]
    public void Development_is_not_checked()
    {
        ProductionConfigurationGuard.FindProblems(Config(new()), new Env("Development"), "1234").Should().BeEmpty();
    }

    private static IConfiguration Config(Dictionary<string, string?> values) =>
        new ConfigurationBuilder().AddInMemoryCollection(values).Build();

    private sealed class Env(string name) : IHostEnvironment
    {
        public string EnvironmentName { get; set; } = name;
        public string ApplicationName { get; set; } = "Rallyto.Host";
        public string ContentRootPath { get; set; } = string.Empty;
        public IFileProvider ContentRootFileProvider { get; set; } = new NullFileProvider();
    }
}
