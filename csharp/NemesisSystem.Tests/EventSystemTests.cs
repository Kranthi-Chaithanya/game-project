using NemesisSystem;
using Xunit;

namespace NemesisSystem.Tests;

public class EventSystemTests
{
    private static (RelationshipManager mgr, Character hero, Character villain) Setup()
    {
        var mgr     = new RelationshipManager();
        var hero    = new Character("hero",    "Arthur",  CharacterType.Player);
        var villain = new Character("villain", "Morgath", CharacterType.Villain);
        mgr.AddCharacter(hero);
        mgr.AddCharacter(villain);
        return (mgr, hero, villain);
    }

    private static RelationshipEvent MakeEvent(EventType type, Character src, Character tgt, string desc = "event")
        => new RelationshipEvent(Guid.NewGuid().ToString(), type, src, tgt, desc);

    [Fact]
    public void ProcessEvent_Betrayal_DecreasesIntensity()
    {
        var (mgr, hero, villain) = Setup();
        mgr.ProcessEvent(MakeEvent(EventType.Betrayal, villain, hero, "Villain betrayed hero"));

        var rel = mgr.GetRelationship(hero, villain)!;
        Assert.Equal(-40, rel.Intensity); // started at 0, -40
    }

    [Fact]
    public void ProcessEvent_Assistance_IncreasesIntensity()
    {
        var (mgr, hero, villain) = Setup();
        mgr.ProcessEvent(MakeEvent(EventType.Assistance, hero, villain, "Hero helped villain"));

        var rel = mgr.GetRelationship(hero, villain)!;
        Assert.Equal(20, rel.Intensity);
    }

    [Fact]
    public void ProcessEvent_MultipleBetrayal_TransitionsToNemesis()
    {
        var (mgr, hero, villain) = Setup();

        // Three betrayals: 3 * -40 = -120 → clamped to -100 → Nemesis
        for (int i = 0; i < 3; i++)
            mgr.ProcessEvent(MakeEvent(EventType.Betrayal, villain, hero));

        var rel = mgr.GetRelationship(hero, villain)!;
        Assert.Equal(RelationshipType.Nemesis, rel.GetPerspective(hero));
        Assert.Equal(RelationshipType.Nemesis, rel.GetPerspective(villain));
    }

    [Fact]
    public void ProcessEvent_MultipleAssistance_TransitionsToAlly()
    {
        var (mgr, hero, villain) = Setup();

        // 4 assistances: 4 * +20 = +80 → Ally (>60)
        for (int i = 0; i < 4; i++)
            mgr.ProcessEvent(MakeEvent(EventType.Assistance, hero, villain));

        var rel = mgr.GetRelationship(hero, villain)!;
        Assert.Equal(RelationshipType.Ally, rel.GetPerspective(hero));
        Assert.Equal(RelationshipType.Ally, rel.GetPerspective(villain));
    }

    [Fact]
    public void ProcessEvent_AllyThenBetray_TransitionsToBetrayer()
    {
        var mgr     = new RelationshipManager();
        var hero    = new Character("hero2",    "Arthur",  CharacterType.Player);
        var villain = new Character("villain2", "Morgath", CharacterType.Villain);

        // Seed relationship with Friend perspectives at intensity=40 (Friend range: 30–60)
        mgr.CreateRelationship(hero, villain, RelationshipType.Friend, RelationshipType.Friend, 40);

        // A single large betrayal drops intensity from 40 to -40, landing in (-80, -30].
        // Since the perspective was Friend at the time of the event, DetermineType returns Betrayer.
        mgr.EventSystem.SetRule(EventType.Betrayal, -80);
        mgr.ProcessEvent(MakeEvent(EventType.Betrayal, villain, hero));

        var rel = mgr.GetRelationship(hero, villain)!;
        Assert.Equal(-40, rel.Intensity);
        Assert.Equal(RelationshipType.Betrayer, rel.GetPerspective(hero));
        Assert.Equal(RelationshipType.Betrayer, rel.GetPerspective(villain));
    }

    [Fact]
    public void ProcessEvent_Callback_Fires()
    {
        var (mgr, hero, villain) = Setup();
        int callCount = 0;
        mgr.EventSystem.OnRelationshipChanged += (_, _) => callCount++;

        mgr.ProcessEvent(MakeEvent(EventType.Combat, hero, villain));
        Assert.Equal(1, callCount);
    }

    [Fact]
    public void ProcessEvent_CallbackReceivesCorrectRelationship()
    {
        var (mgr, hero, villain) = Setup();
        Relationship? captured = null;
        mgr.EventSystem.OnRelationshipChanged += (rel, _) => captured = rel;

        mgr.ProcessEvent(MakeEvent(EventType.Gift, hero, villain, "A gift"));

        Assert.NotNull(captured);
        Assert.Equal(15, captured!.Intensity);
    }

    [Fact]
    public void ProcessEvent_RecordsHistoryEntry()
    {
        var (mgr, hero, villain) = Setup();
        mgr.ProcessEvent(MakeEvent(EventType.Rescue, hero, villain, "Hero rescued villain"));

        var rel = mgr.GetRelationship(hero, villain)!;
        Assert.Single(rel.History);
        Assert.Equal("Hero rescued villain", rel.History[0].EventDescription);
        Assert.Equal(30, rel.History[0].IntensityDelta);
    }

    [Fact]
    public void SetRule_OverridesDefaultDelta()
    {
        var (mgr, hero, villain) = Setup();
        mgr.EventSystem.SetRule(EventType.Combat, -50);

        mgr.ProcessEvent(MakeEvent(EventType.Combat, hero, villain));
        Assert.Equal(-50, mgr.GetRelationship(hero, villain)!.Intensity);
    }

    [Fact]
    public void ProcessEvent_AutoCreatesRelationship_WhenNotExists()
    {
        var mgr  = new RelationshipManager();
        var newA = new Character("n1", "Nova",  CharacterType.NPC);
        var newB = new Character("n2", "Orion", CharacterType.NPC);

        mgr.ProcessEvent(MakeEvent(EventType.Dialogue, newA, newB));
        Assert.NotNull(mgr.GetRelationship(newA, newB));
    }
}
