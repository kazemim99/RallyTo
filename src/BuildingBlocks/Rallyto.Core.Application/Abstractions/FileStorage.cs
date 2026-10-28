namespace Rallyto.Core.Application.Abstractions;

/// <summary>
/// Stores uploaded files under unguessable keys (design D12). Local disk on a mounted volume, as in AsanRezerve;
/// an S3-compatible adapter can replace it when there is more than one instance.
/// </summary>
public interface IFileStorage
{
    /// <param name="folder">For example <c>avatars</c>.</param>
    /// <returns>The public path, for example <c>/media/avatars/3f…9a.jpg</c>.</returns>
    Task<string> SaveAsync(string folder, string extension, Stream content, CancellationToken cancellationToken = default);

    Task DeleteAsync(string publicPath, CancellationToken cancellationToken = default);

    /// <summary>Copies a stored file under a new key in <paramref name="folder"/>, e.g. a reported photo kept as evidence.</summary>
    /// <returns>The copy's public path, or null when the source does not exist.</returns>
    Task<string?> CopyAsync(string publicPath, string folder, CancellationToken cancellationToken = default);
}
