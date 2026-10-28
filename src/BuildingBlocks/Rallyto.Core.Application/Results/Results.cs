namespace Rallyto.Core.Application.Results;

public sealed record ErrorResult(string Code, string Message)
{
    public static ErrorResult NotFound(string what) => new("NOT_FOUND", $"{what} was not found");

    public static ErrorResult Validation(string message) => new("VALIDATION_ERROR", message);
}

public class Result
{
    protected Result(ErrorResult? error) => Error = error;

    public ErrorResult? Error { get; }

    public bool IsSuccess => Error is null;

    public bool IsFailure => !IsSuccess;

    public static Result Success() => new(null);

    public static Result Failure(ErrorResult error) => new(error);

    public static Result Failure(string code, string message) => new(new ErrorResult(code, message));
}

public sealed class Result<T> : Result
{
    private readonly T? _value;

    private Result(T? value, ErrorResult? error) : base(error) => _value = value;

    public T Value => IsSuccess
        ? _value!
        : throw new InvalidOperationException($"A failed result has no value ({Error})");

    public static Result<T> Success(T value) => new(value, null);

    public static new Result<T> Failure(ErrorResult error) => new(default, error);

    public static new Result<T> Failure(string code, string message) => new(default, new ErrorResult(code, message));

    public static implicit operator Result<T>(T value) => Success(value);

    public static implicit operator Result<T>(ErrorResult error) => Failure(error);

    public Result<TOut> Map<TOut>(Func<T, TOut> map) => IsSuccess ? Result<TOut>.Success(map(Value)) : Result<TOut>.Failure(Error!);

    public TOut Match<TOut>(Func<T, TOut> onSuccess, Func<ErrorResult, TOut> onFailure) =>
        IsSuccess ? onSuccess(Value) : onFailure(Error!);
}

/// <summary>Offset paging for admin lists.</summary>
public sealed record PagedResult<T>(IReadOnlyList<T> Items, int Page, int PageSize, int TotalCount)
{
    public int TotalPages => PageSize == 0 ? 0 : (int)Math.Ceiling(TotalCount / (double)PageSize);
}

/// <summary>Keyset paging for player-facing feeds (search, chat history, inbox).</summary>
public sealed record CursorPage<T>(IReadOnlyList<T> Items, string? NextCursor);
