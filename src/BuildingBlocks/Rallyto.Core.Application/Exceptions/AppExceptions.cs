namespace Rallyto.Core.Application.Exceptions;

/// <summary>
/// Base of the errors the application layer raises on purpose. Mapped to <see cref="StatusCode"/> and
/// <see cref="ErrorCode"/> by the exception middleware. Messages are Persian: they reach the user.
/// </summary>
public abstract class AppException : Exception
{
    protected AppException(string errorCode, string message) : base(message) => ErrorCode = errorCode;

    public string ErrorCode { get; }

    public abstract int StatusCode { get; }
}

public sealed class NotFoundException(string message = "مورد درخواستی پیدا نشد", string errorCode = "NOT_FOUND")
    : AppException(errorCode, message)
{
    public override int StatusCode => 404;
}

public sealed class ForbiddenException(string message = "اجازهٔ این کار را ندارید", string errorCode = "FORBIDDEN")
    : AppException(errorCode, message)
{
    public override int StatusCode => 403;
}

public sealed class UnauthorizedException(string message = "ابتدا وارد شوید", string errorCode = "UNAUTHORIZED")
    : AppException(errorCode, message)
{
    public override int StatusCode => 401;
}

public sealed class ConflictException(string errorCode, string message) : AppException(errorCode, message)
{
    public override int StatusCode => 409;
}

public sealed class ValidationFailedException(string errorCode, string message) : AppException(errorCode, message)
{
    public override int StatusCode => 400;
}

public sealed class TooManyRequestsException(string message, TimeSpan? retryAfter, string errorCode = "TOO_MANY_REQUESTS")
    : AppException(errorCode, message)
{
    public TimeSpan? RetryAfter { get; } = retryAfter;

    public override int StatusCode => 429;
}

public sealed class ExternalServiceException(string errorCode, string message) : AppException(errorCode, message)
{
    public override int StatusCode => 503;
}
