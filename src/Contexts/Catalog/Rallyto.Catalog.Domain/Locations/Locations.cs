using Rallyto.Core.Domain.Base;

namespace Rallyto.Catalog.Domain.Locations;

/// <summary>One of Iran's 31 provinces. Seeded reference data with stable ids.</summary>
public sealed class Province : Entity<int>
{
    private Province() { }

    public Province(int id, string name) : base(id) => Name = name;

    public string Name { get; private set; } = string.Empty;
}

public sealed class City : Entity<int>
{
    private City() { }

    public City(int id, int provinceId, string name) : base(id)
    {
        ProvinceId = provinceId;
        Name = name;
    }

    public int ProvinceId { get; private set; }
    public string Name { get; private set; } = string.Empty;
}
