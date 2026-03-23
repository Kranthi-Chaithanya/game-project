namespace NemesisSystem;

public class Relationship
{
    public Character CharacterA { get; }
    public Character CharacterB { get; }

    /// <summary>Perspectives keyed by character Id.</summary>
    public Dictionary<string, RelationshipType> Perspectives { get; } = new();

    private int _intensity;
    public int Intensity
    {
        get => _intensity;
        private set => _intensity = Math.Clamp(value, -100, 100);
    }

    public List<HistoryEntry> History { get; } = new();
    public DateTime CreatedAt { get; }
    public DateTime UpdatedAt { get; private set; }

    public Relationship(Character characterA, Character characterB,
        RelationshipType typeA = RelationshipType.Neutral,
        RelationshipType typeB = RelationshipType.Neutral,
        int intensity = 0)
    {
        CharacterA = characterA;
        CharacterB = characterB;
        CreatedAt = DateTime.UtcNow;
        UpdatedAt = CreatedAt;
        Intensity = intensity;
        Perspectives[characterA.Id] = typeA;
        Perspectives[characterB.Id] = typeB;
    }

    public RelationshipType GetPerspective(Character character)
    {
        if (Perspectives.TryGetValue(character.Id, out var type))
            return type;
        throw new ArgumentException($"Character '{character.Id}' is not part of this relationship.");
    }

    public void SetPerspective(Character character, RelationshipType type)
    {
        if (!Perspectives.ContainsKey(character.Id))
            throw new ArgumentException($"Character '{character.Id}' is not part of this relationship.");
        Perspectives[character.Id] = type;
        UpdatedAt = DateTime.UtcNow;
    }

    public void AddHistory(HistoryEntry entry)
    {
        History.Add(entry);
        UpdatedAt = DateTime.UtcNow;
    }

    public void UpdateIntensity(int delta)
    {
        Intensity = _intensity + delta;
        UpdatedAt = DateTime.UtcNow;
    }
}
