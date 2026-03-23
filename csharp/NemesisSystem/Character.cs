namespace NemesisSystem;

public class Character
{
    public string Id { get; }
    public string Name { get; }
    public CharacterType Type { get; }

    internal RelationshipManager? Manager { private get; set; }

    public Character(string id, string name, CharacterType type)
    {
        Id = id;
        Name = name;
        Type = type;
    }

    public IReadOnlyList<Relationship> GetRelationships()
    {
        if (Manager is null)
            return Array.Empty<Relationship>();
        return Manager.GetRelationshipsFor(this);
    }
}
