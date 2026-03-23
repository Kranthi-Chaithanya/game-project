namespace NemesisSystem;

public class EventSystem
{
    private readonly Dictionary<EventType, int> _rules = new()
    {
        [EventType.Betrayal]   = -40,
        [EventType.Murder]     = -50,
        [EventType.Theft]      = -20,
        [EventType.Combat]     = -10,
        [EventType.Defeat]     = -15,
        [EventType.Victory]    = +10,
        [EventType.Assistance] = +20,
        [EventType.Rescue]     = +30,
        [EventType.Gift]       = +15,
        [EventType.Trade]      = +5,
        [EventType.Dialogue]   = +5,
        [EventType.Quest]      = +10,
    };

    public event Action<Relationship, RelationshipEvent>? OnRelationshipChanged;

    public void SetRule(EventType eventType, int delta) => _rules[eventType] = delta;

    public void ProcessEvent(RelationshipEvent evt, RelationshipManager manager)
    {
        // Ensure both characters are registered
        manager.AddCharacter(evt.Source);
        manager.AddCharacter(evt.Target);

        var relationship = manager.GetRelationship(evt.Source, evt.Target)
            ?? manager.CreateRelationship(evt.Source, evt.Target);

        int delta = _rules.TryGetValue(evt.EventType, out int d) ? d : 0;

        relationship.UpdateIntensity(delta);

        // Determine new relationship type from source's perspective based on thresholds
        var currentTypeFromSource = relationship.GetPerspective(evt.Source);
        var newTypeFromSource = DetermineType(relationship.Intensity, currentTypeFromSource);
        relationship.SetPerspective(evt.Source, newTypeFromSource);

        // Mirror the symmetric perspective from the target
        var currentTypeFromTarget = relationship.GetPerspective(evt.Target);
        var newTypeFromTarget = DetermineType(relationship.Intensity, currentTypeFromTarget);
        relationship.SetPerspective(evt.Target, newTypeFromTarget);

        relationship.AddHistory(new HistoryEntry(evt.Description, evt.Timestamp, delta));

        OnRelationshipChanged?.Invoke(relationship, evt);
    }

    private static RelationshipType DetermineType(int intensity, RelationshipType current)
    {
        if (intensity <= -80)
            return RelationshipType.Nemesis;

        if (intensity is > -80 and <= -30)
        {
            // Betray former friends/allies
            if (current is RelationshipType.Ally or RelationshipType.Friend)
                return RelationshipType.Betrayer;
            return RelationshipType.Rival;
        }

        if (intensity is > -30 and <= 30)
            return RelationshipType.Neutral;

        if (intensity is > 30 and <= 60)
            return RelationshipType.Friend;

        // intensity > 60
        return RelationshipType.Ally;
    }
}
