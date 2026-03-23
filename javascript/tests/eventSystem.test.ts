import { RelationshipManager } from '../src/RelationshipManager';
import { Character } from '../src/Character';
import { CharacterType } from '../src/CharacterType';
import { RelationshipEvent } from '../src/RelationshipEvent';
import { EventType } from '../src/EventType';
import { RelationshipType } from '../src/RelationshipType';

function setup() {
  const manager = new RelationshipManager();
  const hero = new Character('hero', 'Hero', CharacterType.Player);
  const villain = new Character('villain', 'Villain', CharacterType.Villain);
  manager.addCharacter(hero);
  manager.addCharacter(villain);
  return { manager, hero, villain };
}

describe('EventSystem', () => {
  it('processing a Combat event decreases intensity', () => {
    const { manager, hero, villain } = setup();
    const rel = manager.createRelationship(hero, villain);
    const event = new RelationshipEvent(EventType.Combat, hero, villain, 'They fought');
    manager.processEvent(event);
    expect(rel.intensity).toBeLessThan(0);
  });

  it('processing an Assistance event increases intensity', () => {
    const { manager, hero, villain } = setup();
    const rel = manager.createRelationship(hero, villain);
    const event = new RelationshipEvent(EventType.Assistance, hero, villain, 'Helped out');
    manager.processEvent(event);
    expect(rel.intensity).toBeGreaterThan(0);
  });

  it('intensity ≤ -80 transitions both to Nemesis', () => {
    const { manager, hero, villain } = setup();
    manager.createRelationship(hero, villain);
    manager.updateIntensity(hero, villain, -85);
    const rel = manager.getRelationship(hero, villain)!;
    // Manually set perspective to reflect the intensity
    // Process a tiny event to trigger transition logic
    const event = new RelationshipEvent(EventType.Dialogue, hero, villain, 'Brief chat');
    manager.processEvent(event);
    // intensity is now -80 (was -85, +5 from Dialogue)
    // For ≤-80 threshold testing, set intensity explicitly and test
    manager.updateIntensity(hero, villain, -10); // now -85 again
    const event2 = new RelationshipEvent(EventType.Combat, hero, villain, 'Battle');
    manager.processEvent(event2);
    expect(rel.getPerspective(hero)).toBe(RelationshipType.Nemesis);
    expect(rel.getPerspective(villain)).toBe(RelationshipType.Nemesis);
  });

  it('Betrayal event triggers Betrayer transition from Ally', () => {
    const { manager, hero, villain } = setup();
    const rel = manager.createRelationship(hero, villain);
    // Set villain's perspective to Ally so betrayal can transition to Betrayer
    rel.setPerspective(villain, RelationshipType.Ally);
    const event = new RelationshipEvent(EventType.Betrayal, hero, villain, 'Stabbed in back');
    manager.processEvent(event);
    // villain's perspective of hero should become Betrayer
    expect(rel.getPerspective(villain)).toBe(RelationshipType.Betrayer);
  });

  it('callback fires on relationship type change', () => {
    const { manager, hero, villain } = setup();
    manager.createRelationship(hero, villain);
    const callback = jest.fn();
    manager.eventSystem.addCallback(callback);
    // Betrayal from Neutral triggers a transition (Neutral -> Rival or lower)
    const event = new RelationshipEvent(EventType.Betrayal, hero, villain, 'Betrayed');
    manager.processEvent(event);
    expect(callback).toHaveBeenCalled();
  });

  it('history is recorded on event processing', () => {
    const { manager, hero, villain } = setup();
    const rel = manager.createRelationship(hero, villain);
    const event = new RelationshipEvent(EventType.Trade, hero, villain, 'Traded goods');
    manager.processEvent(event);
    expect(rel.history).toHaveLength(1);
    expect(rel.history[0].eventDescription).toBe('Traded goods');
    expect(rel.history[0].intensityDelta).toBe(5);
  });

  it('custom rule overrides default delta', () => {
    const { manager, hero, villain } = setup();
    const rel = manager.createRelationship(hero, villain);
    manager.eventSystem.setRule(EventType.Trade, 50);
    const event = new RelationshipEvent(EventType.Trade, hero, villain, 'Big trade');
    manager.processEvent(event);
    expect(rel.intensity).toBe(50);
  });

  it('creates relationship automatically if not existing', () => {
    const { manager, hero, villain } = setup();
    expect(manager.getRelationship(hero, villain)).toBeUndefined();
    const event = new RelationshipEvent(EventType.Gift, hero, villain, 'Gave a gift');
    manager.processEvent(event);
    expect(manager.getRelationship(hero, villain)).toBeDefined();
  });

  it('intensity between -30 and 30 is Neutral type', () => {
    const { manager, hero, villain } = setup();
    const rel = manager.createRelationship(hero, villain);
    // Start at 0, process Dialogue (+5), stays Neutral
    const event = new RelationshipEvent(EventType.Dialogue, hero, villain, 'Chatted');
    manager.processEvent(event);
    expect(rel.getPerspective(hero)).toBe(RelationshipType.Neutral);
    expect(rel.getPerspective(villain)).toBe(RelationshipType.Neutral);
  });

  it('intensity > 60 transitions to Ally', () => {
    const { manager, hero, villain } = setup();
    manager.createRelationship(hero, villain);
    manager.updateIntensity(hero, villain, 60);
    // Process a Rescue (+30) to push to >60 and trigger transition
    const event = new RelationshipEvent(EventType.Rescue, hero, villain, 'Rescued');
    manager.processEvent(event);
    const rel = manager.getRelationship(hero, villain)!;
    expect(rel.getPerspective(hero)).toBe(RelationshipType.Ally);
    expect(rel.getPerspective(villain)).toBe(RelationshipType.Ally);
  });
});
