import { Character } from '../src/Character';
import { CharacterType } from '../src/CharacterType';
import { Relationship } from '../src/Relationship';
import { RelationshipType } from '../src/RelationshipType';

function makeChars() {
  const a = new Character('a', 'Alice', CharacterType.Player);
  const b = new Character('b', 'Bob', CharacterType.NPC);
  return { a, b };
}

describe('Relationship', () => {
  it('initialises both perspectives as Neutral', () => {
    const { a, b } = makeChars();
    const rel = new Relationship(a, b);
    expect(rel.getPerspective(a)).toBe(RelationshipType.Neutral);
    expect(rel.getPerspective(b)).toBe(RelationshipType.Neutral);
  });

  it('allows setting perspectives independently (bidirectional)', () => {
    const { a, b } = makeChars();
    const rel = new Relationship(a, b);
    rel.setPerspective(a, RelationshipType.Ally);
    rel.setPerspective(b, RelationshipType.Nemesis);
    expect(rel.getPerspective(a)).toBe(RelationshipType.Ally);
    expect(rel.getPerspective(b)).toBe(RelationshipType.Nemesis);
  });

  it('clamps intensity to -100 on large negative delta', () => {
    const { a, b } = makeChars();
    const rel = new Relationship(a, b);
    rel.updateIntensity(-200);
    expect(rel.intensity).toBe(-100);
  });

  it('clamps intensity to 100 on large positive delta', () => {
    const { a, b } = makeChars();
    const rel = new Relationship(a, b);
    rel.updateIntensity(200);
    expect(rel.intensity).toBe(100);
  });

  it('accumulates intensity across multiple updates', () => {
    const { a, b } = makeChars();
    const rel = new Relationship(a, b);
    rel.updateIntensity(30);
    rel.updateIntensity(-10);
    expect(rel.intensity).toBe(20);
  });

  it('adds history entries', () => {
    const { a, b } = makeChars();
    const rel = new Relationship(a, b);
    const entry = { eventDescription: 'fought', timestamp: new Date(), intensityDelta: -10 };
    rel.addHistory(entry);
    expect(rel.history).toHaveLength(1);
    expect(rel.history[0].eventDescription).toBe('fought');
  });

  it('tracks createdAt and updatedAt timestamps', () => {
    const { a, b } = makeChars();
    const before = new Date();
    const rel = new Relationship(a, b);
    const after = new Date();
    expect(rel.createdAt.getTime()).toBeGreaterThanOrEqual(before.getTime());
    expect(rel.createdAt.getTime()).toBeLessThanOrEqual(after.getTime());
  });

  it('updatedAt changes after updateIntensity', () => {
    const { a, b } = makeChars();
    const rel = new Relationship(a, b);
    const original = rel.updatedAt.getTime();
    rel.updateIntensity(5);
    expect(rel.updatedAt.getTime()).toBeGreaterThanOrEqual(original);
  });

  it('involves() returns true for members and false for strangers', () => {
    const { a, b } = makeChars();
    const c = new Character('c', 'Carol', CharacterType.Villain);
    const rel = new Relationship(a, b);
    expect(rel.involves(a)).toBe(true);
    expect(rel.involves(b)).toBe(true);
    expect(rel.involves(c)).toBe(false);
  });

  it('throws when getting perspective of non-member', () => {
    const { a, b } = makeChars();
    const c = new Character('c', 'Carol', CharacterType.Villain);
    const rel = new Relationship(a, b);
    expect(() => rel.getPerspective(c)).toThrow();
  });
});
