using NemesisSystem;
using Xunit;

namespace NemesisSystem.Tests;

public class RelationshipTests
{
    private static (Character, Character) MakePair() =>
        (new Character("a", "Alice", CharacterType.Player),
         new Character("b", "Bob",   CharacterType.NPC));

    [Fact]
    public void Relationship_DefaultPerspectives_AreBothNeutral()
    {
        var (a, b) = MakePair();
        var rel = new Relationship(a, b);

        Assert.Equal(RelationshipType.Neutral, rel.GetPerspective(a));
        Assert.Equal(RelationshipType.Neutral, rel.GetPerspective(b));
    }

    [Fact]
    public void Relationship_CustomPerspectives_SetCorrectly()
    {
        var (a, b) = MakePair();
        var rel = new Relationship(a, b, RelationshipType.Ally, RelationshipType.Nemesis);

        Assert.Equal(RelationshipType.Ally,   rel.GetPerspective(a));
        Assert.Equal(RelationshipType.Nemesis, rel.GetPerspective(b));
    }

    [Fact]
    public void Relationship_SetPerspective_UpdatesBothIndependently()
    {
        var (a, b) = MakePair();
        var rel = new Relationship(a, b);

        rel.SetPerspective(a, RelationshipType.Friend);
        Assert.Equal(RelationshipType.Friend,  rel.GetPerspective(a));
        Assert.Equal(RelationshipType.Neutral, rel.GetPerspective(b));
    }

    [Fact]
    public void Relationship_Intensity_ClampedAtMax()
    {
        var (a, b) = MakePair();
        var rel = new Relationship(a, b, intensity: 90);
        rel.UpdateIntensity(50); // would be 140 without clamping
        Assert.Equal(100, rel.Intensity);
    }

    [Fact]
    public void Relationship_Intensity_ClampedAtMin()
    {
        var (a, b) = MakePair();
        var rel = new Relationship(a, b, intensity: -90);
        rel.UpdateIntensity(-50);
        Assert.Equal(-100, rel.Intensity);
    }

    [Fact]
    public void Relationship_AddHistory_RecordsEntry()
    {
        var (a, b) = MakePair();
        var rel = new Relationship(a, b);
        var entry = new HistoryEntry("Alice rescued Bob", DateTime.UtcNow, +30);

        rel.AddHistory(entry);

        Assert.Single(rel.History);
        Assert.Equal("Alice rescued Bob", rel.History[0].EventDescription);
        Assert.Equal(30, rel.History[0].IntensityDelta);
    }

    [Fact]
    public void Relationship_GetPerspective_UnknownCharacter_Throws()
    {
        var (a, b) = MakePair();
        var stranger = new Character("z", "Zara", CharacterType.Neutral);
        var rel = new Relationship(a, b);

        Assert.Throws<ArgumentException>(() => rel.GetPerspective(stranger));
    }
}
