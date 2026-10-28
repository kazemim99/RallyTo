using MediatR;

namespace Rallyto.Core.Application.Cqrs;

public interface ICommand : IRequest;

public interface ICommand<out TResponse> : IRequest<TResponse>;

public interface ICommandHandler<in TCommand> : IRequestHandler<TCommand>
    where TCommand : ICommand;

public interface ICommandHandler<in TCommand, TResponse> : IRequestHandler<TCommand, TResponse>
    where TCommand : ICommand<TResponse>;

/// <summary>
/// A read request. Caching is opt-in through the default members below; only queries on the allowlist in
/// <c>Rallyto.ArchitectureTests</c> may set <see cref="IsCacheable"/> (design D12).
/// </summary>
public interface IQuery<out TResponse> : IRequest<TResponse>
{
    bool IsCacheable => false;
    string? CacheKey => null;
    int? CacheExpirationSeconds => null;
    IReadOnlyCollection<string>? CacheTags => null;
}

public interface IQueryHandler<in TQuery, TResponse> : IRequestHandler<TQuery, TResponse>
    where TQuery : IQuery<TResponse>;
