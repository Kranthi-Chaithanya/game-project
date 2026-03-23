import { RelationshipManager } from '../src/RelationshipManager';
import { Character } from '../src/Character';
import { CharacterType } from '../src/CharacterType';
import { RelationshipType } from '../src/RelationshipType';

function setup() {
  const manager = new RelationshipManager();
  const hero = new Character('hero', 'Hero', CharacterType.Player);
  const villain = new Character('villain', 'Villain', CharacterType.Villain);
  const npc = new Character('npc', 'NPC', CharacterType.NPC);
  manager.addCharacter(hero);
  manager.addCharacter(villain);
  manager.addCharacter(npc);
  return { manager, hero, villain, npc };
}

describe('RelationshipManager', () => {
  it('creates a relationship between two characters', () => {
    const { manager, hero, villain } = setup();
    const rel = manager.createRelationship(hero, villain);
    expect(rel).toBeDefined();
    expect(rel.involves(hero)).toBe(true);
    expect(rel.involves(villain)).toBe(true);
  });

  it('retrieves an existing relationship', () => {
    const { manager, hero, villain } = setup();
    manager.createRelationship(hero, villain);
    const rel = manager.getRelationship(hero, villain);
    expect(rel).toBeDefined();
  });

  it('returns the same relationship regardless of argument order', () => {
    const { manager, hero, villain } = setup();
    const r1 = manager.createRelationship(hero, villain);
    const r2 = manager.getRelationship(villain, hero);
    expect(r1).toBe(r2);
  });

  it('returns existing relationship on duplicate createRelationship', () => {
    const { manager, hero, villain } = setup();
    const r1 = manager.createRelationship(hero, villain);
    const r2 = manager.createRelationship(hero, villain);
    expect(r1).toBe(r2);
  });

  it('throws on self-relationship', () => {
    const { manager, hero } = setup();
    expect(() => manager.createRelationship(hero, hero)).toThrow();
  });

  it('gets all relationships for a character', () => {
    const { manager, hero, villain, npc } = setup();
    manager.createRelationship(hero, villain);
    manager.createRelationship(hero, npc);
    const rels = manager.getRelationshipsFor(hero);
    expect(rels).toHaveLength(2);
  });

  it('returns characters by type', () => {
    const { manager } = setup();
    const villains = manager.getCharactersByType(CharacterType.Villain);
    expect(villains).toHaveLength(1);
    expect(villains[0].name).toBe('Villain');
  });

  it('updates relationship intensity', () => {
    const { manager, hero, villain } = setup();
    manager.createRelationship(hero, villain);
    manager.updateIntensity(hero, villain, -30);
    const rel = manager.getRelationship(hero, villain)!;
    expect(rel.intensity).toBe(-30);
  });

  it('changes relationship type for a character perspective', () => {
    const { manager, hero, villain } = setup();
    manager.createRelationship(hero, villain);
    manager.changeType(hero, villain, RelationshipType.Nemesis);
    const rel = manager.getRelationship(hero, villain)!;
    expect(rel.getPerspective(hero)).toBe(RelationshipType.Nemesis);
  });

  it('removes a relationship', () => {
    const { manager, hero, villain } = setup();
    manager.createRelationship(hero, villain);
    manager.removeRelationship(hero, villain);
    expect(manager.getRelationship(hero, villain)).toBeUndefined();
  });

  it('character.getRelationships() works via manager', () => {
    const { manager, hero, villain, npc } = setup();
    manager.createRelationship(hero, villain);
    manager.createRelationship(hero, npc);
    expect(hero.getRelationships()).toHaveLength(2);
  });
});
