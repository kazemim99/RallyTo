using Rallyto.Core.Domain.Abstractions;

namespace Rallyto.Core.Domain.Exceptions;

/// <summary>
/// Base of every error the domain raises on purpose. The API maps it to <see cref="HttpStatusCode"/>
/// with <see cref="ErrorCode"/> in the error envelope.
/// </summary>
public abstract class DomainException : Exception
{
    protected DomainException(string message) : base(message) { }

    public abstract string ErrorCode { get; }

    public virtual int HttpStatusCode => 400;

    public IReadOnlyDictionary<string, object?> Details { get; init; } = new Dictionary<string, object?>();
}

public sealed class BusinessRuleViolationException : DomainException
{
    public BusinessRuleViolationException(IBusinessRule rule) : base(rule.Message)
    {
        ErrorCode = rule.ErrorCode;
        RuleName = rule.GetType().Name;
    }

    public BusinessRuleViolationException(string errorCode, string message) : base(message)
    {
        ErrorCode = errorCode;
        RuleName = errorCode;
    }

    public override string ErrorCode { get; }

    public string RuleName { get; }
}

/// <summary>An operation is not allowed in the aggregate's current state (409).</summary>
public sealed class InvalidAggregateStateException : DomainException
{
    public InvalidAggregateStateException(string errorCode, string message) : base(message) => ErrorCode = errorCode;

    public override string ErrorCode { get; }

    public override int HttpStatusCode => 409;
}
