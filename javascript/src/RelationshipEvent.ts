import { EventType } from './EventType';
import { Character } from './Character';

export class RelationshipEvent {
  eventId: string;
  eventType: EventType;
  source: Character;
  target: Character;
  description: string;
  timestamp: Date;

  constructor(eventType: EventType, source: Character, target: Character, description: string) {
    this.eventId = crypto.randomUUID();
    this.eventType = eventType;
    this.source = source;
    this.target = target;
    this.description = description;
    this.timestamp = new Date();
  }
}
