using System.Diagnostics.CodeAnalysis;
using Rallyto.Core.Domain.Base;
using Rallyto.Core.Domain.Exceptions;

namespace Rallyto.Identity.Domain;

/// <summary>
/// An Iranian mobile number, normalised to E.164 (<c>+989xxxxxxxxx</c>). Only the Identity context holds phone
/// numbers (design D11); everyone else knows a user by id.
/// </summary>
public sealed class PhoneNumber : ValueObject
{
    private PhoneNumber(string value) => Value = value;

    public string Value { get; }

    /// <summary><c>09xxxxxxxxx</c>, the form SMS providers expect.</summary>
    public string LocalForm => "0" + Value[3..];

    public static PhoneNumber Parse(string? input) =>
        TryParse(input, out var phone)
            ? phone
            : throw new BusinessRuleViolationException("INVALID_PHONE_NUMBER", "شمارهٔ موبایل معتبر نیست.");

    /// <summary>
    /// Accepts <c>09xxxxxxxxx</c>, <c>9xxxxxxxxx</c>, <c>989xxxxxxxxx</c>, <c>+989xxxxxxxxx</c> and <c>00989xxxxxxxxx</c>,
    /// with Persian or Arabic-Indic digits and spaces, dashes or parentheses.
    /// </summary>
    public static bool TryParse(string? input, [NotNullWhen(true)] out PhoneNumber? phone)
    {
        phone = null;
        if (string.IsNullOrWhiteSpace(input))
            return false;

        var digits = new List<char>(16);
        foreach (var raw in input.Trim())
        {
            var c = raw switch
            {
                >= '۰' and <= '۹' => (char)('0' + (raw - '۰')),
                >= '٠' and <= '٩' => (char)('0' + (raw - '٠')),
                _ => raw,
            };
            if (char.IsAsciiDigit(c))
                digits.Add(c);
            else if (c is not (' ' or '-' or '(' or ')' or '+'))
                return false;
        }

        var number = new string([.. digits]);
        if (number.StartsWith("0098", StringComparison.Ordinal))
            number = number[4..];
        else if (number.StartsWith("98", StringComparison.Ordinal) && number.Length == 12)
            number = number[2..];
        else if (number.StartsWith('0') && number.Length == 11)
            number = number[1..];

        if (number.Length != 10 || number[0] != '9')
            return false;

        phone = new PhoneNumber("+98" + number);
        return true;
    }

    protected override IEnumerable<object?> GetAtomicValues()
    {
        yield return Value;
    }

    public override string ToString() => Value;
}
