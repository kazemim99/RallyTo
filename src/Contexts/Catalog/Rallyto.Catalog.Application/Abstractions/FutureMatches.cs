using Rallyto.Core.Domain.SharedKernel;

namespace Rallyto.Catalog.Application.Abstractions;

/// <summary>
/// Whether future games use a sport's format; implemented by the host from Community (design D3). Catalog never
/// references Community directly.
/// </summary>
public interface IFutureMatchReader
{
    Task<bool> FormatInUseAsync(Guid sportId, PlayFormat format, CancellationToken cancellationToken);
}
