using System.Security.Cryptography;
using Microsoft.Extensions.Configuration;
using Rallyto.Core.Application.Abstractions;

namespace Rallyto.Infrastructure.Core.Storage;

public sealed class StorageOptions
{
    public const string SectionName = "Storage";
    public const string PublicPrefix = "/media";

    /// <summary>Folder on disk (a mounted volume in containers).</summary>
    public string RootPath { get; set; } = "uploads";

    public static string ResolveRoot(IConfiguration configuration) =>
        Path.GetFullPath(configuration.GetSection(SectionName)["RootPath"] ?? "uploads");
}

/// <summary>Files on local disk under random 128-bit names; served read-only under <c>/media</c> by the host.</summary>
public sealed class LocalFileStorage(IConfiguration configuration) : IFileStorage
{
    private readonly string _root = StorageOptions.ResolveRoot(configuration);

    public async Task<string> SaveAsync(string folder, string extension, Stream content, CancellationToken cancellationToken = default)
    {
        if (folder.Any(c => !char.IsAsciiLetterLower(c)) || extension.Any(c => !char.IsAsciiLetterLower(c)))
            throw new ArgumentException("Folder and extension must be lowercase ASCII letters.");
        var name = $"{Convert.ToHexString(RandomNumberGenerator.GetBytes(16)).ToLowerInvariant()}.{extension}";
        var directory = Path.Combine(_root, folder);
        Directory.CreateDirectory(directory);
        await using (var file = File.Create(Path.Combine(directory, name)))
            await content.CopyToAsync(file, cancellationToken);
        return $"{StorageOptions.PublicPrefix}/{folder}/{name}";
    }

    public Task DeleteAsync(string publicPath, CancellationToken cancellationToken = default)
    {
        if (Resolve(publicPath) is { } full && File.Exists(full))
            File.Delete(full);
        return Task.CompletedTask;
    }

    public async Task<string?> CopyAsync(string publicPath, string folder, CancellationToken cancellationToken = default)
    {
        if (Resolve(publicPath) is not { } full || !File.Exists(full))
            return null;
        await using var source = File.OpenRead(full);
        return await SaveAsync(folder, Path.GetExtension(full).TrimStart('.'), source, cancellationToken);
    }

    /// <summary>The file behind a public path, or null for a path outside the storage root.</summary>
    private string? Resolve(string publicPath)
    {
        if (!publicPath.StartsWith(StorageOptions.PublicPrefix + "/", StringComparison.Ordinal))
            return null;
        var relative = publicPath[(StorageOptions.PublicPrefix.Length + 1)..].Replace('/', Path.DirectorySeparatorChar);
        var full = Path.GetFullPath(Path.Combine(_root, relative));
        return full.StartsWith(_root, StringComparison.Ordinal) ? full : null;
    }
}
