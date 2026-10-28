using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace Rallyto.Tests.Commons.Api;

public sealed record ApiError(string Code, string Message);

/// <summary>A response unwrapped from the <c>{ success, statusCode, data, error, metadata }</c> envelope.</summary>
public sealed class ApiResponse<T>
{
    public required HttpStatusCode Status { get; init; }
    public T? Data { get; init; }
    public ApiError? Error { get; init; }
    public required HttpResponseMessage Raw { get; init; }

    public string? ErrorCode => Error?.Code;
}

public static class ApiClient
{
    public static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web)
    {
        Converters = { new JsonStringEnumConverter() },
    };

    public static Task<ApiResponse<T>> PostApiAsync<T>(this HttpClient client, string url, object? body = null) =>
        SendAsync<T>(client, HttpMethod.Post, url, body);

    public static Task<ApiResponse<T>> PutApiAsync<T>(this HttpClient client, string url, object? body = null) =>
        SendAsync<T>(client, HttpMethod.Put, url, body);

    public static Task<ApiResponse<T>> GetApiAsync<T>(this HttpClient client, string url) =>
        SendAsync<T>(client, HttpMethod.Get, url, null);

    public static Task<ApiResponse<T>> DeleteApiAsync<T>(this HttpClient client, string url, object? body = null) =>
        SendAsync<T>(client, HttpMethod.Delete, url, body);

    public static HttpClient WithBearer(this HttpClient client, string accessToken)
    {
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", accessToken);
        return client;
    }

    private static async Task<ApiResponse<T>> SendAsync<T>(HttpClient client, HttpMethod method, string url, object? body)
    {
        using var request = new HttpRequestMessage(method, url);
        if (body is not null)
            request.Content = JsonContent.Create(body, body.GetType(), options: Json);
        var response = await client.SendAsync(request);
        var text = await response.Content.ReadAsStringAsync();

        T? data = default;
        ApiError? error = null;
        if (!string.IsNullOrWhiteSpace(text) && text.TrimStart().StartsWith('{'))
        {
            using var document = JsonDocument.Parse(text);
            var root = document.RootElement;
            if (root.TryGetProperty("data", out var dataElement) && dataElement.ValueKind != JsonValueKind.Null)
                data = dataElement.Deserialize<T>(Json);
            if (root.TryGetProperty("error", out var errorElement) && errorElement.ValueKind == JsonValueKind.Object)
                error = new ApiError(errorElement.GetProperty("code").GetString() ?? string.Empty, errorElement.GetProperty("message").GetString() ?? string.Empty);
        }

        return new ApiResponse<T> { Status = response.StatusCode, Data = data, Error = error, Raw = response };
    }
}

/// <summary>Use when the response body does not matter.</summary>
public sealed record Empty;
