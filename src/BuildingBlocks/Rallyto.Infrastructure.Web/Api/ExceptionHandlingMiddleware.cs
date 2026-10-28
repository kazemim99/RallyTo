using System.Globalization;
using System.Text.Json;
using FluentValidation;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Rallyto.Core.Application.Exceptions;
using Rallyto.Core.Domain.Exceptions;

namespace Rallyto.Infrastructure.Web.Api;

/// <summary>
/// Turns exceptions into the error envelope
/// <c>{ success:false, statusCode, message, data:null, error:{ code, message, errors }, metadata }</c>.
/// Ported from AsanRezerve's ExceptionHandlingMiddleware; <c>statusCode</c> is a number here, as on success.
/// </summary>
public sealed class ExceptionHandlingMiddleware(RequestDelegate next, ILogger<ExceptionHandlingMiddleware> logger, IHostEnvironment environment)
{
    public async Task InvokeAsync(HttpContext context)
    {
        try
        {
            await next(context);
        }
        catch (Exception ex)
        {
            await HandleAsync(context, ex);
        }
    }

    private async Task HandleAsync(HttpContext context, Exception exception)
    {
        if (context.Response.HasStarted)
        {
            logger.LogError(exception, "Request {Method} {Path} failed after the response started", context.Request.Method, context.Request.Path.Value);
            return;
        }

        var error = Map(exception, context.Response);
        Log(context, exception, error.Status, error.Code);
        await WriteErrorAsync(context, error.Status, error.Code, error.Message, error.Errors);
    }

    public static async Task WriteErrorAsync(HttpContext context, int status, string code, string message, IDictionary<string, string[]>? errors = null)
    {
        context.Response.StatusCode = status;
        context.Response.ContentType = "application/json; charset=utf-8";
        using var stream = new MemoryStream();
        await using (var writer = new Utf8JsonWriter(stream, new JsonWriterOptions { Encoder = JsonDefaults.Encoder }))
        {
            writer.WriteStartObject();
            writer.WriteBoolean("success", false);
            writer.WriteNumber("statusCode", status);
            writer.WriteString("message", message);
            writer.WriteNull("data");
            writer.WriteStartObject("error");
            writer.WriteString("code", code);
            writer.WriteString("message", message);
            if (errors is { Count: > 0 })
            {
                writer.WriteStartObject("errors");
                foreach (var (key, values) in errors)
                {
                    writer.WriteStartArray(JsonNamingPolicy.CamelCase.ConvertName(key));
                    foreach (var value in values)
                        writer.WriteStringValue(value);
                    writer.WriteEndArray();
                }

                writer.WriteEndObject();
            }

            writer.WriteEndObject();
            ApiResponseMiddleware.WriteMetadata(writer, context, null, null);
            writer.WriteEndObject();
        }

        await context.Response.Body.WriteAsync(stream.ToArray(), context.RequestAborted);
    }

    private (int Status, string Code, string Message, IDictionary<string, string[]>? Errors) Map(Exception exception, HttpResponse response)
    {
        switch (exception)
        {
            case DomainException domain:
                return (domain.HttpStatusCode, domain.ErrorCode, domain.Message, null);
            case TooManyRequestsException tooMany:
                if (tooMany.RetryAfter is { } retryAfter)
                    response.Headers.RetryAfter = ((int)Math.Ceiling(Math.Max(retryAfter.TotalSeconds, 1))).ToString(CultureInfo.InvariantCulture);
                return (tooMany.StatusCode, tooMany.ErrorCode, tooMany.Message, null);
            case AppException app:
                return (app.StatusCode, app.ErrorCode, app.Message, null);
            case ValidationException validation:
                var errors = validation.Errors
                    .GroupBy(e => e.PropertyName)
                    .ToDictionary(g => g.Key, g => g.Select(e => e.ErrorMessage).ToArray());
                var first = validation.Errors.FirstOrDefault()?.ErrorMessage ?? "اطلاعات واردشده معتبر نیست";
                var code = validation.Errors.FirstOrDefault(e => !string.IsNullOrEmpty(e.ErrorCode) && !e.ErrorCode.EndsWith("Validator", StringComparison.Ordinal))?.ErrorCode ?? "VALIDATION_ERROR";
                return (StatusCodes.Status400BadRequest, code, first, errors);
            case DbUpdateConcurrencyException:
                return (StatusCodes.Status409Conflict, "CONCURRENCY_CONFLICT", "این مورد همزمان تغییر کرد. دوباره تلاش کنید.", null);
            case Exception unique when IsUniqueViolation(unique):
                return (StatusCodes.Status409Conflict, "DUPLICATE_CONFLICT", "این مورد قبلاً ثبت شده است.", null);
            case BadHttpRequestException badRequest:
                return (badRequest.StatusCode, "BAD_REQUEST", "درخواست نامعتبر است.", null);
            case OperationCanceledException:
                return (499, "CANCELLED", "درخواست لغو شد.", null);
            default:
                var detail = environment.IsDevelopment() || environment.IsEnvironment("Testing") ? exception.Message : "خطای داخلی رخ داد. لطفاً دوباره تلاش کنید.";
                return (StatusCodes.Status500InternalServerError, "INTERNAL_ERROR", detail, null);
        }
    }

    private void Log(HttpContext context, Exception exception, int status, string code)
    {
        if (status >= 500)
            logger.LogError(exception, "Request {Method} {Path} failed with {StatusCode} {ErrorCode}", context.Request.Method, context.Request.Path.Value, status, code);
        else
            logger.LogInformation("Request {Method} {Path} was rejected with {StatusCode} {ErrorCode}: {ExceptionType}", context.Request.Method, context.Request.Path.Value, status, code, exception.GetType().Name);
    }

    private static bool IsUniqueViolation(Exception exception)
    {
        for (var e = exception; e is not null; e = e.InnerException)
        {
            if (e.GetType().Name == "PostgresException" && e.GetType().GetProperty("SqlState")?.GetValue(e) as string == "23505")
                return true;
        }

        return false;
    }
}
