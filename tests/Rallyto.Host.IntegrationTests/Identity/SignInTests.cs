using System.Net;
using Rallyto.Host.IntegrationTests.Infrastructure;
using Rallyto.Tests.Commons;
using Rallyto.Tests.Commons.Api;

namespace Rallyto.Host.IntegrationTests.Identity;

/// <summary>spec identity-access: normalisation, requesting a code, verifying it.</summary>
public sealed class SignInTests(RallytoHostFactory factory) : IntegrationTestBase(factory)
{
    private const string Phone = "09123456789";

    [Fact]
    public async Task Persian_digits_are_normalised()
    {
        using var client = Factory.CreateClient();

        var response = await client.PostApiAsync<SendCodeResponse>(IdentityApi.SendCode, new { phoneNumber = "۰۹۱۲۳۴۵۶۷۸۹" });

        response.Status.Should().Be(HttpStatusCode.OK);
        Factory.Sms.CountFor(Phone).Should().Be(1);
    }

    [Theory]
    [InlineData("+989123456789")]
    [InlineData("989123456789")]
    [InlineData("00989123456789")]
    [InlineData("9123456789")]
    [InlineData("٠٩١٢٣٤٥٦٧٨٩")]
    public async Task Every_accepted_form_reaches_the_same_number(string input)
    {
        using var client = Factory.CreateClient();

        await client.PostApiAsync<SendCodeResponse>(IdentityApi.SendCode, new { phoneNumber = input });

        Factory.Sms.CountFor(Phone).Should().Be(1);
    }

    [Fact]
    public async Task Landline_number_is_rejected()
    {
        using var client = Factory.CreateClient();

        var response = await client.PostApiAsync<SendCodeResponse>(IdentityApi.SendCode, new { phoneNumber = "02188776655" });

        response.Status.Should().Be(HttpStatusCode.BadRequest);
        response.ErrorCode.Should().Be("INVALID_PHONE_NUMBER");
        Factory.Sms.Sent.Should().BeEmpty();
    }

    [Fact]
    public async Task First_code_request_sends_a_four_digit_code_valid_for_five_minutes()
    {
        using var client = Factory.CreateClient();

        var response = await client.PostApiAsync<SendCodeResponse>(IdentityApi.SendCode, new { phoneNumber = Phone });

        response.Status.Should().Be(HttpStatusCode.OK);
        response.Data!.ExpiresInSeconds.Should().Be(300);
        response.Data.ResendAfterSeconds.Should().Be(60);
        Factory.Sms.LastCodeFor(Phone).Should().MatchRegex("^[0-9]{4}$");
    }

    [Fact]
    public async Task Resend_inside_the_cooldown_is_rejected_with_retry_after()
    {
        using var client = Factory.CreateClient();
        await client.PostApiAsync<SendCodeResponse>(IdentityApi.SendCode, new { phoneNumber = Phone });
        Factory.Advance(TimeSpan.FromSeconds(30));

        var response = await client.PostApiAsync<SendCodeResponse>(IdentityApi.SendCode, new { phoneNumber = Phone });

        response.Status.Should().Be(HttpStatusCode.TooManyRequests);
        response.Raw.Headers.RetryAfter!.Delta.Should().Be(TimeSpan.FromSeconds(30));
        Factory.Sms.CountFor(Phone).Should().Be(1);
    }

    [Fact]
    public async Task Fourth_send_inside_ten_minutes_is_rejected()
    {
        using var client = Factory.CreateClient();
        for (var i = 0; i < 3; i++)
        {
            (await client.PostApiAsync<SendCodeResponse>(IdentityApi.SendCode, new { phoneNumber = Phone })).Status.Should().Be(HttpStatusCode.OK);
            Factory.Advance(TimeSpan.FromSeconds(61));
        }

        var fourth = await client.PostApiAsync<SendCodeResponse>(IdentityApi.SendCode, new { phoneNumber = Phone });

        fourth.Status.Should().Be(HttpStatusCode.TooManyRequests);
        Factory.Sms.CountFor(Phone).Should().Be(3);
    }

    [Fact]
    public async Task Sms_provider_failure_cancels_the_code()
    {
        using var client = Factory.CreateClient();
        Factory.Sms.Fail = true;

        var response = await client.PostApiAsync<SendCodeResponse>(IdentityApi.SendCode, new { phoneNumber = Phone });
        var verify = await client.PostApiAsync<AuthTokens>(IdentityApi.Verify, new { phoneNumber = Phone, code = Factory.Sms.LastCodeFor(Phone) });

        response.Status.Should().Be(HttpStatusCode.ServiceUnavailable);
        response.ErrorCode.Should().Be("SMS_SEND_FAILED");
        verify.Status.Should().Be(HttpStatusCode.BadRequest);
    }

    [Fact]
    public async Task New_user_signs_in_as_an_active_player_without_a_profile()
    {
        var tokens = await Factory.SignInAsync(Phone);

        tokens.Roles.Should().BeEquivalentTo("Player");
        tokens.ProfileCompleted.Should().BeFalse();
        tokens.AccessTokenExpiresAt.Should().Be(RallytoHostFactory.DefaultNow.UtcDateTime.AddMinutes(60));
        tokens.RefreshTokenExpiresAt.Should().Be(RallytoHostFactory.DefaultNow.UtcDateTime.AddDays(30));

        using var client = Factory.CreateClient().WithBearer(tokens.AccessToken);
        var me = await client.GetApiAsync<MyAccount>(IdentityApi.Me);
        me.Data!.PhoneNumber.Should().Be("+989123456789");
        me.Data.Status.Should().Be("Active");
    }

    [Fact]
    public async Task Returning_user_signs_in_to_the_same_account()
    {
        var first = await Factory.SignInAsync(Phone);
        Factory.Advance(TimeSpan.FromMinutes(2));
        var second = await Factory.SignInAsync(Phone);

        using var a = Factory.CreateClient().WithBearer(first.AccessToken);
        using var b = Factory.CreateClient().WithBearer(second.AccessToken);
        (await IdentityApi.UserIdOf(a)).Should().Be(await IdentityApi.UserIdOf(b));
    }

    [Fact]
    public async Task Five_wrong_codes_block_verification_for_an_hour()
    {
        using var client = Factory.CreateClient();
        await client.PostApiAsync<SendCodeResponse>(IdentityApi.SendCode, new { phoneNumber = Phone });
        var correct = Factory.Sms.LastCodeFor(Phone);
        var wrong = correct == "0000" ? "1111" : "0000";
        for (var i = 0; i < 5; i++)
            await client.PostApiAsync<AuthTokens>(IdentityApi.Verify, new { phoneNumber = Phone, code = wrong });

        var withCorrectCode = await client.PostApiAsync<AuthTokens>(IdentityApi.Verify, new { phoneNumber = Phone, code = correct });

        withCorrectCode.Status.Should().Be(HttpStatusCode.TooManyRequests);
        withCorrectCode.ErrorCode.Should().Be("VERIFICATION_BLOCKED");
    }

    [Fact]
    public async Task Block_ends_after_an_hour()
    {
        using var client = Factory.CreateClient();
        await client.PostApiAsync<SendCodeResponse>(IdentityApi.SendCode, new { phoneNumber = Phone });
        var wrong = Factory.Sms.LastCodeFor(Phone) == "0000" ? "1111" : "0000";
        for (var i = 0; i < 5; i++)
            await client.PostApiAsync<AuthTokens>(IdentityApi.Verify, new { phoneNumber = Phone, code = wrong });
        Factory.Advance(TimeSpan.FromMinutes(61));

        var tokens = await Factory.SignInAsync(Phone);

        tokens.AccessToken.Should().NotBeNullOrEmpty();
    }

    [Fact]
    public async Task Expired_code_is_rejected()
    {
        using var client = Factory.CreateClient();
        await client.PostApiAsync<SendCodeResponse>(IdentityApi.SendCode, new { phoneNumber = Phone });
        Factory.Advance(TimeSpan.FromMinutes(6));

        var response = await client.PostApiAsync<AuthTokens>(IdentityApi.Verify, new { phoneNumber = Phone, code = Factory.Sms.LastCodeFor(Phone) });

        response.Status.Should().Be(HttpStatusCode.BadRequest);
        response.ErrorCode.Should().Be("CODE_EXPIRED");
    }

    [Fact]
    public async Task A_code_works_only_once()
    {
        await Factory.SignInAsync(Phone);
        using var client = Factory.CreateClient();

        var reuse = await client.PostApiAsync<AuthTokens>(IdentityApi.Verify, new { phoneNumber = Phone, code = Factory.Sms.LastCodeFor(Phone) });

        reuse.Status.Should().Be(HttpStatusCode.BadRequest);
        reuse.ErrorCode.Should().Be("CODE_INVALID");
    }

    [Fact]
    public async Task Only_the_latest_code_is_valid()
    {
        using var client = Factory.CreateClient();
        await client.PostApiAsync<SendCodeResponse>(IdentityApi.SendCode, new { phoneNumber = Phone });
        var first = Factory.Sms.LastCodeFor(Phone);
        Factory.Advance(TimeSpan.FromSeconds(61));
        await client.PostApiAsync<SendCodeResponse>(IdentityApi.SendCode, new { phoneNumber = Phone });
        var second = Factory.Sms.LastCodeFor(Phone);

        var withFirst = await client.PostApiAsync<AuthTokens>(IdentityApi.Verify, new { phoneNumber = Phone, code = first });
        var withSecond = await client.PostApiAsync<AuthTokens>(IdentityApi.Verify, new { phoneNumber = Phone, code = second });

        if (first != second)
            withFirst.Status.Should().Be(HttpStatusCode.BadRequest);
        withSecond.Status.Should().Be(HttpStatusCode.OK);
    }
}
