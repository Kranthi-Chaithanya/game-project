import { CharacterType } from './CharacterType';
import { Relationship } from './Relationship';

export class Character {
  id: string;
  name: string;
  characterType: CharacterType;
  private _manager: { getRelationshipsFor(character: Character): Relationship[] } | null = null;

  constructor(id: string, name: string, characterType: CharacterType) {
    this.id = id;
    this.name = name;
    this.characterType = characterType;
  }

  setManager(manager: { getRelationshipsFor(character: Character): Relationship[] }): void {
    this._manager = manager;
  }

  getRelationships(): Relationship[] {
    if (!this._manager) return [];
    return this._manager.getRelationshipsFor(this);
  }

  toString(): string {
    return `Character(${this.id}, ${this.name}, ${this.characterType})`;
  }
}
