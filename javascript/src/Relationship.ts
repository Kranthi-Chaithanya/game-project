import { Character } from './Character';
import { RelationshipType } from './RelationshipType';
import { HistoryEntry } from './HistoryEntry';

export class Relationship {
  characterA: Character;
  characterB: Character;
  perspectives: Map<string, RelationshipType>;
  private _intensity: number;
  history: HistoryEntry[];
  createdAt: Date;
  updatedAt: Date;

  constructor(characterA: Character, characterB: Character) {
    this.characterA = characterA;
    this.characterB = characterB;
    this.perspectives = new Map<string, RelationshipType>();
    this.perspectives.set(characterA.id, RelationshipType.Neutral);
    this.perspectives.set(characterB.id, RelationshipType.Neutral);
    this._intensity = 0;
    this.history = [];
    this.createdAt = new Date();
    this.updatedAt = new Date();
  }

  get intensity(): number {
    return this._intensity;
  }

  getPerspective(character: Character): RelationshipType {
    const type = this.perspectives.get(character.id);
    if (type === undefined) {
      throw new Error(`Character ${character.id} is not part of this relationship`);
    }
    return type;
  }

  setPerspective(character: Character, type: RelationshipType): void {
    if (!this.perspectives.has(character.id)) {
      throw new Error(`Character ${character.id} is not part of this relationship`);
    }
    this.perspectives.set(character.id, type);
    this.updatedAt = new Date();
  }

  addHistory(entry: HistoryEntry): void {
    this.history.push(entry);
    this.updatedAt = new Date();
  }

  updateIntensity(delta: number): void {
    this._intensity = Math.max(-100, Math.min(100, this._intensity + delta));
    this.updatedAt = new Date();
  }

  involves(character: Character): boolean {
    return this.characterA.id === character.id || this.characterB.id === character.id;
  }
}
