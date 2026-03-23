namespace NemesisSystem;

public class RelationshipManager
{
    private readonly Dictionary<string, Character> _characters = new();
    private readonly Dictionary<string, Relationship> _relationships = new();
    private readonly EventSystem _eventSystem = new();

    // Stable key regardless of argument order
    private static string RelationshipKey(string idA, string idB)
    {
        var (a, b) = string.Compare(idA, idB, StringComparison.Ordinal) <= 0 ? (idA, idB) : (idB, idA);
        return $"{a}::{b}";
    }

    public void AddCharacter(Character character)
    {
        if (!_characters.ContainsKey(character.Id))
        {
            _characters[character.Id] = character;
            character.Manager = this;
        }
    }

    public Relationship CreateRelationship(
        Character charA,
        Character charB,
        RelationshipType typeA = RelationshipType.Neutral,
        RelationshipType typeB = RelationshipType.Neutral,
        int intensity = 0)
    {
        if (charA.Id == charB.Id)
            throw new InvalidOperationException("A character cannot have a relationship with itself.");

        var key = RelationshipKey(charA.Id, charB.Id);
        if (_relationships.TryGetValue(key, out var existing))
            return existing;

        AddCharacter(charA);
        AddCharacter(charB);

        var relationship = new Relationship(charA, charB, typeA, typeB, intensity);
        _relationships[key] = relationship;
        return relationship;
    }

    public Relationship? GetRelationship(Character charA, Character charB)
    {
        var key = RelationshipKey(charA.Id, charB.Id);
        return _relationships.TryGetValue(key, out var r) ? r : null;
    }

    public IReadOnlyList<Relationship> GetRelationshipsFor(Character character)
    {
        return _relationships.Values
            .Where(r => r.CharacterA.Id == character.Id || r.CharacterB.Id == character.Id)
            .ToList();
    }

    public IReadOnlyList<Character> GetCharactersByType(Character character, RelationshipType type)
    {
        return GetRelationshipsFor(character)
            .Where(r => r.Perspectives.TryGetValue(character.Id, out var t) && t == type)
            .Select(r => r.CharacterA.Id == character.Id ? r.CharacterB : r.CharacterA)
            .ToList();
    }

    public void UpdateIntensity(Character charA, Character charB, int delta)
    {
        var rel = GetRelationship(charA, charB)
            ?? throw new InvalidOperationException("Relationship not found.");
        rel.UpdateIntensity(delta);
    }

    public void ChangeType(
        Character charA,
        Character charB,
        RelationshipType typeFromA,
        RelationshipType? typeFromB = null)
    {
        var rel = GetRelationship(charA, charB)
            ?? throw new InvalidOperationException("Relationship not found.");
        rel.SetPerspective(charA, typeFromA);
        if (typeFromB.HasValue)
            rel.SetPerspective(charB, typeFromB.Value);
    }

    public bool RemoveRelationship(Character charA, Character charB)
    {
        var key = RelationshipKey(charA.Id, charB.Id);
        return _relationships.Remove(key);
    }

    public void ProcessEvent(RelationshipEvent evt) => _eventSystem.ProcessEvent(evt, this);

    public EventSystem EventSystem => _eventSystem;
}
