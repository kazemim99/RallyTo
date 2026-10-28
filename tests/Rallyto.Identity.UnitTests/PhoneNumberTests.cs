using Rallyto.Core.Domain.Exceptions;
using Rallyto.Identity.Domain;

namespace Rallyto.Identity.UnitTests;

public sealed class PhoneNumberTests
{
    [Theory]
    [InlineData("09123456789")]
    [InlineData("9123456789")]
    [InlineData("989123456789")]
    [InlineData("+989123456789")]
    [InlineData("00989123456789")]
    [InlineData("۰۹۱۲۳۴۵۶۷۸۹")]
    [InlineData("٠٩١٢٣٤٥٦٧٨٩")]
    [InlineData("0912 345 6789")]
    [InlineData("(0912) 345-6789")]
    public void Every_accepted_form_normalises_to_E164(string input)
    {
        var phone = PhoneNumber.Parse(input);

        phone.Value.Should().Be("+989123456789");
        phone.LocalForm.Should().Be("09123456789");
    }

    [Theory]
    [InlineData("02188776655")]
    [InlineData("0912345678")]
    [InlineData("091234567890")]
    [InlineData("08123456789")]
    [InlineData("abc")]
    [InlineData("")]
    [InlineData(null)]
    [InlineData("+14155550100")]
    public void Non_mobile_numbers_are_rejected(string? input)
    {
        PhoneNumber.TryParse(input, out _).Should().BeFalse();
        var parse = () => PhoneNumber.Parse(input);
        parse.Should().Throw<BusinessRuleViolationException>().Which.ErrorCode.Should().Be("INVALID_PHONE_NUMBER");
    }

    [Fact]
    public void Equal_numbers_in_different_forms_are_equal()
    {
        PhoneNumber.Parse("09123456789").Should().Be(PhoneNumber.Parse("+98 912 345 6789"));
    }
}
