using Asp.Versioning;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Rallyto.Core.Application.Results;
using Rallyto.Identity.Application.Account;
using Rallyto.Identity.Application.Admin;
using Rallyto.Identity.Application.SignIn;
using Rallyto.Identity.Domain.Accounts;
using Rallyto.Infrastructure.Web.RateLimiting;
using Rallyto.Infrastructure.Web.Security;

namespace Rallyto.Identity.Api.Controllers;

public sealed record SendCodeRequest(string PhoneNumber);

public sealed record VerifyCodeRequest(string PhoneNumber, string Code);

public sealed record AdminSignInRequest(string Email, string Password);

public sealed record RefreshTokenRequest(string RefreshToken);

public sealed record DeletionRequest(string Code);

public sealed record SuspendRequest(DateTime Until, string Reason);

public sealed record ReasonRequest(string Reason);

[ApiController]
[ApiVersion("1.0")]
[AllowAnonymous]
[Route("api/v{version:apiVersion}/auth")]
public sealed class AuthController(ISender sender) : ControllerBase
{
    [HttpPost("otp/send")]
    [EnableRateLimiting(RateLimitPolicies.PhoneVerification)]
    public async Task<ActionResult<SendCodeResult>> SendCode(SendCodeRequest request, CancellationToken ct) =>
        Ok(await sender.Send(new SendSignInCodeCommand(request.PhoneNumber), ct));

    /// <summary>The admin panel's sign-in with email and password.</summary>
    [HttpPost("admin/sign-in")]
    [EnableRateLimiting(RateLimitPolicies.AdminSignIn)]
    public async Task<ActionResult<AuthTokens>> AdminSignIn(AdminSignInRequest request, CancellationToken ct) =>
        Ok(await sender.Send(new AdminSignInCommand(request.Email, request.Password), ct));

    [HttpPost("otp/verify")]
    [EnableRateLimiting(RateLimitPolicies.CodeVerification)]
    public async Task<ActionResult<AuthTokens>> Verify(VerifyCodeRequest request, CancellationToken ct) =>
        Ok(await sender.Send(new VerifySignInCodeCommand(request.PhoneNumber, request.Code), ct));

    [HttpPost("refresh")]
    public async Task<ActionResult<AuthTokens>> Refresh(RefreshTokenRequest request, CancellationToken ct) =>
        Ok(await sender.Send(new RefreshTokensCommand(request.RefreshToken), ct));

    [HttpPost("sign-out")]
    public async Task<IActionResult> SignOut(RefreshTokenRequest request, CancellationToken ct)
    {
        await sender.Send(new SignOutCommand(request.RefreshToken), ct);
        return NoContent();
    }
}

[ApiController]
[ApiVersion("1.0")]
[Authorize]
[Route("api/v{version:apiVersion}/account")]
public sealed class AccountController(ISender sender) : ControllerBase
{
    [HttpGet("me")]
    public async Task<ActionResult<MyAccountDto>> Me(CancellationToken ct) => Ok(await sender.Send(new GetMyAccountQuery(), ct));

    [HttpPost("deletion/code")]
    [EnableRateLimiting(RateLimitPolicies.PhoneVerification)]
    public async Task<ActionResult<SendCodeResult>> SendDeletionCode(CancellationToken ct) =>
        Ok(await sender.Send(new SendDeletionCodeCommand(), ct));

    [HttpPost("deletion")]
    public async Task<IActionResult> Delete(DeletionRequest request, CancellationToken ct)
    {
        await sender.Send(new DeleteAccountCommand(request.Code), ct);
        return NoContent();
    }
}

[ApiController]
[ApiVersion("1.0")]
[Authorize(Policy = Policies.AdminOnly)]
[Route("api/v{version:apiVersion}/admin/users")]
public sealed class AdminUsersController(ISender sender) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<PagedResult<AdminAccountDto>>> List(
        [FromQuery] string? search, [FromQuery] AccountStatus? status, [FromQuery] int page = 1, [FromQuery] int pageSize = 20, CancellationToken ct = default) =>
        Ok(await sender.Send(new ListAccountsQuery(search, status, page, pageSize), ct));

    [HttpGet("{userId:guid}")]
    public async Task<ActionResult<AdminAccountDto>> Get(Guid userId, CancellationToken ct) =>
        Ok(await sender.Send(new GetAccountQuery(userId), ct));

    [HttpPost("{userId:guid}/suspend")]
    public Task<IActionResult> Suspend(Guid userId, SuspendRequest request, CancellationToken ct) =>
        Run(new SuspendAccountCommand(userId, request.Until, request.Reason), ct);

    [HttpPost("{userId:guid}/lift-suspension")]
    public Task<IActionResult> LiftSuspension(Guid userId, ReasonRequest request, CancellationToken ct) =>
        Run(new LiftSuspensionCommand(userId, request.Reason), ct);

    [HttpPost("{userId:guid}/ban")]
    public Task<IActionResult> Ban(Guid userId, ReasonRequest request, CancellationToken ct) =>
        Run(new BanAccountCommand(userId, request.Reason), ct);

    [HttpPost("{userId:guid}/roles/admin")]
    public Task<IActionResult> GrantAdmin(Guid userId, CancellationToken ct) => Run(new GrantAdminCommand(userId), ct);

    [HttpDelete("{userId:guid}/roles/admin")]
    public Task<IActionResult> RevokeAdmin(Guid userId, CancellationToken ct) => Run(new RevokeAdminCommand(userId), ct);

    private async Task<IActionResult> Run(IRequest command, CancellationToken ct)
    {
        await sender.Send(command, ct);
        return NoContent();
    }
}
