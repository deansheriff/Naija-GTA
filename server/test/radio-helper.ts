import type {Intent, State} from '../src/rules.js';

// Exercise the public move intent instead of bypassing the radio's validation.
export async function solveRadio(state: State, send: (body: Omit<Intent, 'revision'>) => Promise<State>) {
  for (let tile = 0; tile < 6; tile++) {
    const puzzle = state.active?.puzzle;
    if (!puzzle) break;
    const moves = (puzzle.target[tile] - puzzle.turns[tile] + 4) % 4;
    for (let step = 0; step < moves; step++) state = await send({kind: 'repair_move', tile});
  }
  return state;
}
