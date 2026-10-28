using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Serilog;
using Serilog.Extensions.Logging;
using Serilog.Formatting.Compact;

namespace Rallyto.Infrastructure.Web.Observability;

public sealed class LoggingOptions
{
    public const string SectionName = "Observability:Logging";
    public bool ConsoleEnabled { get; set; } = true;
    public bool FileEnabled { get; set; } = true;
    public string FilePath { get; set; } = "logs/rallyto-host-.clef";
    public int RetainedFileCount { get; set; } = 14;
    public string? SeqServerUrl { get; set; }
    public string? SeqApiKey { get; set; }
}

public static class LoggingPipeline
{
    /// <summary>
    /// Microsoft.Extensions.Logging stays the level gate (<c>Logging:LogLevel</c>); Serilog is only a provider behind it,
    /// writing async console, rolling CLEF files and Seq when configured. Every event is masked first (AsanRezerve's pipeline).
    /// </summary>
    public static ILoggingBuilder AddRallytoLogging(this ILoggingBuilder logging, IConfiguration configuration)
    {
        var options = configuration.GetSection(LoggingOptions.SectionName).Get<LoggingOptions>() ?? new LoggingOptions();
        var logger = new LoggerConfiguration()
            .MinimumLevel.Verbose()
            .Enrich.FromLogContext()
            .Enrich.With(new SensitiveDataMaskingEnricher());

        if (options.ConsoleEnabled)
            logger.WriteTo.Async(sink => sink.Console(outputTemplate: "[{Timestamp:HH:mm:ss} {Level:u3}] {SourceContext}: {Message:lj}{NewLine}{Exception}"));
        if (options.FileEnabled)
            logger.WriteTo.Async(sink => sink.File(new CompactJsonFormatter(), options.FilePath, rollingInterval: RollingInterval.Day, retainedFileCountLimit: options.RetainedFileCount));
        var seq = options.SeqServerUrl ?? configuration["Seq:ServerUrl"];
        if (!string.IsNullOrWhiteSpace(seq))
            logger.WriteTo.Seq(seq, apiKey: options.SeqApiKey);

        logging.ClearProviders();
        logging.AddProvider(new SerilogLoggerProvider(logger.CreateLogger(), dispose: true));
        return logging;
    }
}
