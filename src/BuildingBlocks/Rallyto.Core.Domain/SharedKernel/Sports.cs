namespace Rallyto.Core.Domain.SharedKernel;

/// <summary>
/// The five self-declared level tiers shared by every sport (spec sport-catalog). Catalog owns their wording per
/// sport; Community stores a player's tier. The numeric order is the tier order.
/// </summary>
public enum LevelTier
{
    Beginner = 1,
    LowerIntermediate = 2,
    Intermediate = 3,
    Advanced = 4,
    Professional = 5,
}

public enum PlayFormat
{
    Singles = 1,
    Doubles = 2,
}

public static class LevelTiers
{
    public static int Distance(LevelTier a, LevelTier b) => Math.Abs((int)a - (int)b);

    public static LevelTier Clamp(int value) => (LevelTier)Math.Clamp(value, (int)LevelTier.Beginner, (int)LevelTier.Professional);

    public static bool IsWithin(LevelTier tier, LevelTier min, LevelTier max) => tier >= min && tier <= max;
}
