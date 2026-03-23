import { Character } from '../src/Character';
import { CharacterType } from '../src/CharacterType';

describe('Character', () => {
  it('creates a character with correct properties', () => {
    const char = new Character('1', 'Hero', CharacterType.Player);
    expect(char.id).toBe('1');
    expect(char.name).toBe('Hero');
    expect(char.characterType).toBe(CharacterType.Player);
  });

  it('supports all character types', () => {
    const types = Object.values(CharacterType);
    types.forEach((type, i) => {
      const c = new Character(String(i), `Char${i}`, type);
      expect(c.characterType).toBe(type);
    });
  });

  it('returns empty relationships without a manager', () => {
    const char = new Character('1', 'Hero', CharacterType.Player);
    expect(char.getRelationships()).toEqual([]);
  });

  it('toString returns a descriptive string', () => {
    const char = new Character('42', 'Villain', CharacterType.Villain);
    expect(char.toString()).toContain('42');
    expect(char.toString()).toContain('Villain');
  });

  it('getRelationships delegates to manager after setManager', () => {
    const char = new Character('1', 'A', CharacterType.Player);
    const mockManager = {
      getRelationshipsFor: jest.fn().mockReturnValue(['rel1', 'rel2']),
    };
    char.setManager(mockManager as any);
    const result = char.getRelationships();
    expect(mockManager.getRelationshipsFor).toHaveBeenCalledWith(char);
    expect(result).toEqual(['rel1', 'rel2']);
  });
});
