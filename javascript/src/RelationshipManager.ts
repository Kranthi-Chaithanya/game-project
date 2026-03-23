import { Character } from './Character';
import { CharacterType } from './CharacterType';
import { Relationship } from './Relationship';
import { RelationshipType } from './RelationshipType';
import { EventSystem } from './EventSystem';
import { RelationshipEvent } from './RelationshipEvent';

export class RelationshipManager {
  characters: Map<string, Character>;
  relationships: Map<string, Relationship>;
  eventSystem: EventSystem;

  constructor() {
    this.characters = new Map();
    this.relationships = new Map();
    this.eventSystem = new EventSystem();
  }

  private relationshipKey(a: Character, b: Character): string {
    const ids = [a.id, b.id].sort();
    return `${ids[0]}:${ids[1]}`;
  }

  addCharacter(character: Character): void {
    character.setManager(this);
    this.characters.set(character.id, character);
  }

  createRelationship(characterA: Character, characterB: Character): Relationship {
    if (characterA.id === characterB.id) {
      throw new Error('Cannot create a relationship between a character and themselves');
    }
    const key = this.relationshipKey(characterA, characterB);
    const existing = this.relationships.get(key);
    if (existing) return existing;

    const relationship = new Relationship(characterA, characterB);
    this.relationships.set(key, relationship);
    return relationship;
  }

  getRelationship(characterA: Character, characterB: Character): Relationship | undefined {
    const key = this.relationshipKey(characterA, characterB);
    return this.relationships.get(key);
  }

  getRelationshipsFor(character: Character): Relationship[] {
    return Array.from(this.relationships.values()).filter(r => r.involves(character));
  }

  getCharactersByType(characterType: CharacterType): Character[] {
    return Array.from(this.characters.values()).filter(c => c.characterType === characterType);
  }

  updateIntensity(characterA: Character, characterB: Character, delta: number): void {
    const relationship = this.getRelationship(characterA, characterB);
    if (!relationship) {
      throw new Error('Relationship not found');
    }
    relationship.updateIntensity(delta);
  }

  changeType(
    character: Character,
    target: Character,
    type: RelationshipType
  ): void {
    const relationship = this.getRelationship(character, target);
    if (!relationship) {
      throw new Error('Relationship not found');
    }
    relationship.setPerspective(character, type);
  }

  removeRelationship(characterA: Character, characterB: Character): void {
    const key = this.relationshipKey(characterA, characterB);
    this.relationships.delete(key);
  }

  processEvent(event: RelationshipEvent): void {
    this.eventSystem.processEvent(event, this);
  }
}
