using System.Text.RegularExpressions;
using Serilog.Core;
using Serilog.Events;

namespace Rallyto.Infrastructure.Web.Observability;

/// <summary>
/// Masks secrets, sign-in codes, tokens and phone numbers in every log event before any sink sees it
/// (spec identity-access › Phone number privacy). Ported from AsanRezerve's enricher, without the payment fields.
/// </summary>
public sealed partial class SensitiveDataMaskingEnricher : ILogEventEnricher
{
    public const string Redacted = "***";

    private static readonly HashSet<string> SecretNames = new(StringComparer.Ordinal)
    {
        "password", "code", "otp", "otpcode", "verificationcode", "sandboxcode",
        "token", "accesstoken", "refreshtoken", "idtoken", "secret", "clientsecret", "secretkey",
        "apikey", "authorization", "smsbody", "credentialsjson", "pepper",
    };

    private static readonly string[] SecretSuffixes = ["password", "token", "secret", "apikey", "otp", "otpcode", "hash"];

    private static readonly HashSet<string> PhoneNames = new(StringComparer.Ordinal)
    {
        "phone", "phonenumber", "mobile", "mobilenumber", "recipient", "to", "receptor",
    };

    private enum Kind { None, Secret, Phone }

    public void Enrich(LogEvent logEvent, ILogEventPropertyFactory propertyFactory)
    {
        List<LogEventProperty>? changed = null;
        foreach (var (name, value) in logEvent.Properties)
        {
            var masked = Mask(name, value);
            if (!ReferenceEquals(masked, value))
                (changed ??= []).Add(new LogEventProperty(name, masked));
        }

        changed?.ForEach(logEvent.AddOrUpdateProperty);
    }

    public static LogEventPropertyValue Mask(string? name, LogEventPropertyValue value)
    {
        var kind = Classify(name);
        return value switch
        {
            ScalarValue scalar => MaskScalar(kind, scalar),
            StructureValue structure => MaskStructure(structure),
            SequenceValue sequence => MaskSequence(name, sequence),
            DictionaryValue dictionary => MaskDictionary(dictionary),
            _ => value,
        };
    }

    public static string MaskPhone(string text) =>
        text.Length < 7 ? Redacted : string.Concat(text.AsSpan(0, 4), new string('*', text.Length - 6), text.AsSpan(text.Length - 2));

    public static string? ScrubText(string? text) =>
        string.IsNullOrEmpty(text) ? text : MobileNumberInText().Replace(text, m => MaskPhone(m.Value));

    private static Kind Classify(string? name)
    {
        if (string.IsNullOrEmpty(name))
            return Kind.None;
        var key = Normalize(name);
        if (IsSecret(key) || (key.Length > 1 && key[^1] == 's' && IsSecret(key[..^1])))
            return Kind.Secret;
        if (PhoneNames.Contains(key) || key.Contains("phone", StringComparison.Ordinal) || key.Contains("mobile", StringComparison.Ordinal))
            return Kind.Phone;
        return Kind.None;
    }

    private static bool IsSecret(string key) => SecretNames.Contains(key) || SecretSuffixes.Any(key.EndsWith);

    private static string Normalize(string name) =>
        new(name.Where(c => c is not ('_' or '-' or ' ')).Select(char.ToLowerInvariant).Take(128).ToArray());

    private static LogEventPropertyValue MaskScalar(Kind kind, ScalarValue scalar)
    {
        if (scalar.Value is null)
            return scalar;
        if (kind == Kind.Secret)
            return new ScalarValue(Redacted);
        if (scalar.Value is not string text || text.Contains('*'))
            return scalar;
        if (kind == Kind.Phone || MobileNumber().IsMatch(text))
            return new ScalarValue(MaskPhone(text));
        var scrubbed = ScrubText(text);
        return scrubbed == text ? scalar : new ScalarValue(scrubbed);
    }

    private static LogEventPropertyValue MaskStructure(StructureValue structure)
    {
        var properties = structure.Properties.Select(p => new LogEventProperty(p.Name, Mask(p.Name, p.Value))).ToArray();
        return properties.Zip(structure.Properties).All(pair => ReferenceEquals(pair.First.Value, pair.Second.Value))
            ? structure
            : new StructureValue(properties, structure.TypeTag);
    }

    private static LogEventPropertyValue MaskSequence(string? name, SequenceValue sequence)
    {
        var elements = sequence.Elements.Select(e => Mask(name, e)).ToArray();
        return elements.Zip(sequence.Elements).All(pair => ReferenceEquals(pair.First, pair.Second)) ? sequence : new SequenceValue(elements);
    }

    private static LogEventPropertyValue MaskDictionary(DictionaryValue dictionary)
    {
        var elements = dictionary.Elements
            .Select(kv => new KeyValuePair<ScalarValue, LogEventPropertyValue>(kv.Key, Mask(kv.Key.Value?.ToString(), kv.Value)))
            .ToArray();
        return elements.Zip(dictionary.Elements).All(pair => ReferenceEquals(pair.First.Value, pair.Second.Value))
            ? dictionary
            : new DictionaryValue(elements);
    }

    [GeneratedRegex(@"(?<![\w+])(\+98|0098|98|0)?9\d{9}(?!\w)", RegexOptions.CultureInvariant)]
    private static partial Regex MobileNumberInText();

    [GeneratedRegex(@"^(\+98|0098|98|0)?9\d{9}$", RegexOptions.CultureInvariant)]
    private static partial Regex MobileNumber();
}
