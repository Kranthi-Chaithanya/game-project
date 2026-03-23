using NemesisSystem;
using Xunit;

namespace NemesisSystem.Tests;

public class RelationshipManagerTests
{
    private static (RelationshipManager, Character, Character) Setup()
    {
        var mgr = new RelationshipManager();
        var a = new Character("a", "Alice", CharacterType.Player);
        var b = new Character("b", "Bob",   CharacterType.NPC);
        return (mgr, a, b);
    }

    [Fact]
    public void CreateRelationship_ReturnsRelationshipWithCorrectCharacters()
    {
        var (mgr, a, b) = Setup();
        var rel = mgr.CreateRelationship(a, b);

        Assert.NotNull(rel);
        Assert.True(rel.CharacterA.Id == a.Id || rel.CharacterB.Id == a.Id);
        Assert.True(rel.CharacterA.Id == b.Id || rel.CharacterB.Id == b.Id);
    }

    [Fact]
    public void GetRelationship_ReturnsExistingRelationship()
    {
        var (mgr, a, b) = Setup();
        mgr.CreateRelationship(a, b);

        var rel = mgr.GetRelationship(a, b);
        Assert.NotNull(rel);
    }

    [Fact]
    public void GetRelationship_ReversedOrder_ReturnsSameRelationship()
    {
        var (mgr, a, b) = Setup();
        var created = mgr.CreateRelationship(a, b);
        var fetched = mgr.GetRelationship(b, a);

        Assert.Same(created, fetched);
    }

    [Fact]
    public void GetRelationship_NonExistent_ReturnsNull()
    {
        var (mgr, a, b) = Setup();
        Assert.Null(mgr.GetRelationship(a, b));
    }

    [Fact]
    public void GetRelationshipsFor_ReturnsAllRelationshipsOfCharacter()
    {
        var (mgr, a, b) = Setup();
        var c = new Character("c", "Carol", CharacterType.Ally);
        mgr.CreateRelationship(a, b);
        mgr.CreateRelationship(a, c);

        var rels = mgr.GetRelationshipsFor(a);
        Assert.Equal(2, rels.Count);
    }

    [Fact]
    public void GetCharactersByType_ReturnsOnlyMatchingType()
    {
        var (mgr, a, b) = Setup();
        var c = new Character("c", "Carol", CharacterType.Ally);
        mgr.CreateRelationship(a, b, RelationshipType.Friend, RelationshipType.Friend);
        mgr.CreateRelationship(a, c, RelationshipType.Nemesis, RelationshipType.Nemesis);

        var friends = mgr.GetCharactersByType(a, RelationshipType.Friend);
        Assert.Single(friends);
        Assert.Equal("b", friends[0].Id);
    }

    [Fact]
    public void UpdateIntensity_ChangesIntensityCorrectly()
    {
        var (mgr, a, b) = Setup();
        mgr.CreateRelationship(a, b, intensity: 0);
        mgr.UpdateIntensity(a, b, 25);

        Assert.Equal(25, mgr.GetRelationship(a, b)!.Intensity);
    }

    [Fact]
    public void ChangeType_UpdatesPerspectiveForOneOrBoth()
    {
        var (mgr, a, b) = Setup();
        mgr.CreateRelationship(a, b);

        mgr.ChangeType(a, b, RelationshipType.Ally, RelationshipType.Rival);
        var rel = mgr.GetRelationship(a, b)!;

        Assert.Equal(RelationshipType.Ally,  rel.GetPerspective(a));
        Assert.Equal(RelationshipType.Rival, rel.GetPerspective(b));
    }

    [Fact]
    public void ChangeType_OnlySourcePerspective_TargetUnchanged()
    {
        var (mgr, a, b) = Setup();
        mgr.CreateRelationship(a, b);

        mgr.ChangeType(a, b, RelationshipType.Friend);
        var rel = mgr.GetRelationship(a, b)!;

        Assert.Equal(RelationshipType.Friend,  rel.GetPerspective(a));
        Assert.Equal(RelationshipType.Neutral, rel.GetPerspective(b));
    }

    [Fact]
    public void RemoveRelationship_RemovesSuccessfully()
    {
        var (mgr, a, b) = Setup();
        mgr.CreateRelationship(a, b);
        var removed = mgr.RemoveRelationship(a, b);

        Assert.True(removed);
        Assert.Null(mgr.GetRelationship(a, b));
    }

    [Fact]
    public void CreateRelationship_SelfRelationship_ThrowsException()
    {
        var (mgr, a, _) = Setup();
        Assert.Throws<InvalidOperationException>(() => mgr.CreateRelationship(a, a));
    }

    [Fact]
    public void CreateRelationship_Duplicate_ReturnsExisting()
    {
        var (mgr, a, b) = Setup();
        var first  = mgr.CreateRelationship(a, b);
        var second = mgr.CreateRelationship(a, b);

        Assert.Same(first, second);
    }
}
