import { EventType } from './EventType';
import { RelationshipType } from './RelationshipType';
import { RelationshipEvent } from './RelationshipEvent';
import { RelationshipManager } from './RelationshipManager';
import { Character } from './Character';

type RelationshipChangedCallback = (
  source: Character,
  target: Character,
  oldType: RelationshipType,
  newType: RelationshipType
) => void;

export class EventSystem {
  private rules: Map<EventType, number>;
  onRelationshipChanged: Array<RelationshipChangedCallback>;

  constructor() {
    this.rules = new Map<EventType, number>([
      [EventType.Betrayal, -40],
      [EventType.Murder, -50],
      [EventType.Theft, -20],
      [EventType.Combat, -10],
      [EventType.Defeat, -15],
      [EventType.Victory, 10],
      [EventType.Assistance, 20],
      [EventType.Rescue, 30],
      [EventType.Gift, 15],
      [EventType.Trade, 5],
      [EventType.Dialogue, 5],
      [EventType.Quest, 10],
    ]);
    this.onRelationshipChanged = [];
  }

  setRule(eventType: EventType, delta: number): void {
    this.rules.set(eventType, delta);
  }

  addCallback(fn: RelationshipChangedCallback): void {
    this.onRelationshipChanged.push(fn);
  }

  private determineType(intensity: number, currentType: RelationshipType): RelationshipType {
    if (intensity <= -80) return RelationshipType.Nemesis;
    if (intensity <= -30) return RelationshipType.Rival;
    if (intensity <= 30) return RelationshipType.Neutral;
    if (intensity <= 60) return RelationshipType.Friend;
    return RelationshipType.Ally;
  }

  processEvent(event: RelationshipEvent, manager: RelationshipManager): void {
    const delta = this.rules.get(event.eventType) ?? 0;

    let relationship = manager.getRelationship(event.source, event.target);
    if (!relationship) {
      relationship = manager.createRelationship(event.source, event.target);
    }

    const oldSourceType = relationship.getPerspective(event.source);
    const oldTargetType = relationship.getPerspective(event.target);

    relationship.updateIntensity(delta);
    relationship.addHistory({
      eventDescription: event.description,
      timestamp: event.timestamp,
      intensityDelta: delta,
    });

    const intensity = relationship.intensity;

    // Determine new type for the target's perspective (how target sees source after event)
    let newTargetType: RelationshipType;

    // Betrayer transition: if event was betrayal-like (negative delta) and previous type was Ally/Friend
    if (
      delta < 0 &&
      (oldTargetType === RelationshipType.Ally || oldTargetType === RelationshipType.Friend)
    ) {
      newTargetType = RelationshipType.Betrayer;
    } else {
      newTargetType = this.determineType(intensity, oldTargetType);
    }

    const newSourceType = this.determineType(intensity, oldSourceType);

    if (newTargetType !== oldTargetType) {
      relationship.setPerspective(event.target, newTargetType);
      this.onRelationshipChanged.forEach(cb =>
        cb(event.source, event.target, oldTargetType, newTargetType)
      );
    }

    if (newSourceType !== oldSourceType) {
      relationship.setPerspective(event.source, newSourceType);
      this.onRelationshipChanged.forEach(cb =>
        cb(event.target, event.source, oldSourceType, newSourceType)
      );
    }
  }
}
