using System.Buffers;
using System.Diagnostics;
using System.Text;
using System.Text.Json;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Options;

namespace Rallyto.Infrastructure.Web.Api;

public sealed class ApiResponseOptions
{
    public string ApiPathPrefix { get; set; } = "/api";
    public string ApiVersion { get; set; } = "1.0";
    public bool IncludeMetadata { get; set; } = true;
    public string[] ExcludedPathPrefixes { get; set; } = [];
}

/// <summary>
/// Wraps every successful <c>/api</c> response as <c>{ success, statusCode, message, data, metadata }</c>,
/// the envelope the AsanRezerve clients already parse (ported from AsanRezerve's ApiResponseMiddleware).
/// Errors are written by <see cref="ExceptionHandlingMiddleware"/> in the same shape.
/// </summary>
public sealed class ApiResponseMiddleware(RequestDelegate next, IOptions<ApiResponseOptions> options)
{
    private readonly ApiResponseOptions _options = options.Value;

    public async Task InvokeAsync(HttpContext context)
    {
        if (!IsApiRequest(context.Request))
        {
            await next(context);
            return;
        }

        var started = Stopwatch.GetTimestamp();
        var originalBody = context.Response.Body;
        try
        {
            using var buffer = new MemoryStream();
            context.Response.Body = buffer;
            await next(context);
            context.Response.Body = originalBody;

            var status = context.Response.StatusCode;
            if (status is >= 200 and < 300 && status != StatusCodes.Status204NoContent && !IsDocument(context.Response))
            {
                var wrapped = Wrap(context, buffer, (long)Stopwatch.GetElapsedTime(started).TotalMilliseconds);
                context.Response.ContentType = "application/json; charset=utf-8";
                context.Response.ContentLength = wrapped.WrittenCount;
                await originalBody.WriteAsync(wrapped.WrittenMemory, context.RequestAborted);
                return;
            }

            buffer.Seek(0, SeekOrigin.Begin);
            await buffer.CopyToAsync(originalBody, context.RequestAborted);
        }
        finally
        {
            context.Response.Body = originalBody;
        }
    }

    private ArrayBufferWriter<byte> Wrap(HttpContext context, MemoryStream body, long elapsedMs)
    {
        ReadOnlySpan<byte> content = body.TryGetBuffer(out var segment) ? segment.AsSpan(0, (int)body.Length) : body.ToArray();
        var output = new ArrayBufferWriter<byte>(content.Length + 512);
        using var writer = new Utf8JsonWriter(output, new JsonWriterOptions { Encoder = JsonDefaults.Encoder });
        writer.WriteStartObject();
        writer.WriteBoolean("success", true);
        writer.WriteNumber("statusCode", context.Response.StatusCode);
        writer.WriteString("message", context.Response.StatusCode == StatusCodes.Status201Created ? "Resource created successfully" : "Request completed successfully");
        if (!IsBlank(content))
        {
            writer.WritePropertyName("data");
            if (IsJson(content))
                writer.WriteRawValue(content, skipInputValidation: true);
            else
                writer.WriteStringValue(Encoding.UTF8.GetString(content));
        }

        if (_options.IncludeMetadata)
            WriteMetadata(writer, context, elapsedMs, _options.ApiVersion);
        writer.WriteEndObject();
        writer.Flush();
        return output;
    }

    internal static void WriteMetadata(Utf8JsonWriter writer, HttpContext context, long? elapsedMs, string? version)
    {
        writer.WriteStartObject("metadata");
        writer.WriteString("requestId", context.TraceIdentifier);
        writer.WriteString("traceId", Activity.Current?.TraceId.ToHexString() ?? context.TraceIdentifier);
        writer.WriteString("timestamp", DateTimeOffset.UtcNow);
        if (elapsedMs is { } ms)
            writer.WriteNumber("duration", ms);
        writer.WriteString("path", context.Request.Path.Value);
        writer.WriteString("method", context.Request.Method);
        if (version is not null)
            writer.WriteString("version", version);
        writer.WriteEndObject();
    }

    private static bool IsBlank(ReadOnlySpan<byte> content)
    {
        foreach (var b in content)
        {
            if (b is not ((byte)' ' or (byte)'\t' or (byte)'\r' or (byte)'\n'))
                return false;
        }

        return true;
    }

    private static bool IsJson(ReadOnlySpan<byte> content)
    {
        try
        {
            var reader = new Utf8JsonReader(content);
            if (!reader.Read())
                return false;
            reader.Skip();
            return !reader.Read();
        }
        catch (JsonException)
        {
            return false;
        }
    }

    private static bool IsDocument(HttpResponse response) =>
        response.Headers.ContentDisposition.Count > 0
        || (response.ContentType?.StartsWith("text/html", StringComparison.OrdinalIgnoreCase) ?? false)
        || (response.ContentType?.StartsWith("image/", StringComparison.OrdinalIgnoreCase) ?? false);

    private bool IsApiRequest(HttpRequest request) =>
        request.Path.StartsWithSegments(_options.ApiPathPrefix)
        && !_options.ExcludedPathPrefixes.Any(p => request.Path.StartsWithSegments(p, StringComparison.OrdinalIgnoreCase));
}

public static class JsonDefaults
{
    /// <summary>Writes Persian text as-is instead of \u escapes.</summary>
    public static readonly System.Text.Encodings.Web.JavaScriptEncoder Encoder =
        System.Text.Encodings.Web.JavaScriptEncoder.Create(System.Text.Unicode.UnicodeRanges.All);
}
