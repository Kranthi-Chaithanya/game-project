namespace NemesisSystem;

public class RelationshipEvent
{
    public string EventId { get; }
    public EventType EventType { get; }
    public Character Source { get; }
    public Character Target { get; }
    public string Description { get; }
    public DateTime Timestamp { get; }

    public RelationshipEvent(string eventId, EventType eventType, Character source, Character target, string description)
    {
        EventId = eventId;
        EventType = eventType;
        Source = source;
        Target = target;
        Description = description;
        Timestamp = DateTime.UtcNow;
    }
}
