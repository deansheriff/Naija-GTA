import {randomInt} from 'node:crypto';

export type RadioPuzzle = {turns: number[]; target: number[]; solved: boolean};
export function newRadioPuzzle(): RadioPuzzle {
  const target = Array.from({length: 6}, () => randomInt(4));
  return {target, turns: target.map(turn => (turn + randomInt(1, 4)) % 4), solved: false};
}
export function radioMatches(puzzle: RadioPuzzle): boolean {
  return puzzle.turns.length === 6 && puzzle.turns.every((turn, index) => turn === puzzle.target[index]);
}
