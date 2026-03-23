using NemesisSystem;
using Xunit;

namespace NemesisSystem.Tests;

public class CharacterTests
{
    [Fact]
    public void Character_CreatedWithCorrectProperties()
    {
        var c = new Character("hero-1", "Arthur", CharacterType.Player);
        Assert.Equal("hero-1", c.Id);
        Assert.Equal("Arthur", c.Name);
        Assert.Equal(CharacterType.Player, c.Type);
    }

    [Fact]
    public void Character_DifferentTypes_AssignedCorrectly()
    {
        var villain = new Character("v1", "Morgath", CharacterType.Villain);
        var ally    = new Character("a1", "Lira",   CharacterType.Ally);
        var mentor  = new Character("m1", "Eldrin",  CharacterType.Mentor);

        Assert.Equal(CharacterType.Villain, villain.Type);
        Assert.Equal(CharacterType.Ally,    ally.Type);
        Assert.Equal(CharacterType.Mentor,  mentor.Type);
    }

    [Fact]
    public void Character_WithoutManager_GetRelationships_ReturnsEmpty()
    {
        var c = new Character("x1", "Solo", CharacterType.NPC);
        Assert.Empty(c.GetRelationships());
    }

    [Fact]
    public void Character_WithManager_GetRelationships_ReturnsRelationships()
    {
        var manager = new RelationshipManager();
        var c1 = new Character("c1", "Alice", CharacterType.Player);
        var c2 = new Character("c2", "Bob",   CharacterType.NPC);
        manager.CreateRelationship(c1, c2);

        Assert.Single(c1.GetRelationships());
        Assert.Single(c2.GetRelationships());
    }
}
