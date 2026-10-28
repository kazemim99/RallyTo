using Microsoft.AspNetCore.Http;
using Rallyto.Core.Application.Abstractions;
using Rallyto.Infrastructure.Web.Api;

namespace Rallyto.Infrastructure.Web.Security;

/// <summary>
/// Rejects authenticated requests from accounts that are no longer Active, even while their access token is
/// valid, so suspensions and bans take effect at once (spec identity-access, design D10).
/// </summary>
public sealed class ActiveAccountMiddleware(RequestDelegate next)
{
    public async Task InvokeAsync(HttpContext context, ICurrentUserService currentUser, IAccountStatusReader statusReader)
    {
        if (currentUser.IsAuthenticated && currentUser.UserId is { } userId)
        {
            var status = await statusReader.GetStatusAsync(userId, context.RequestAborted);
            if (status != AccountStatusKind.Active)
            {
                var (code, message) = status switch
                {
                    AccountStatusKind.Suspended => ("ACCOUNT_SUSPENDED", "حساب کاربری شما موقتاً مسدود شده است."),
                    AccountStatusKind.Banned => ("ACCOUNT_BANNED", "حساب کاربری شما مسدود شده است."),
                    _ => ("ACCOUNT_INACTIVE", "حساب کاربری فعال نیست."),
                };
                await ExceptionHandlingMiddleware.WriteErrorAsync(context, StatusCodes.Status401Unauthorized, code, message);
                return;
            }
        }

        await next(context);
    }
}
