export const actions = {
  learn: {seconds: 8, cost: 0, energy: 8},
  gig: {seconds: 10, cost: 0, energy: 12},
  eat: {seconds: 6, cost: 25, energy: 0},
  rest: {seconds: 8, cost: 0, energy: 0},
  wash: {seconds: 5, cost: 0, energy: 0},
  study: {seconds: 8, cost: 0, energy: 8}
} as const;
export type Action = keyof typeof actions;
export type State = {
  name: string; bio: string; coins: number; food: number; energy: number; comfort: number;
  repair: number; digital: number; social: number; met_amaka: boolean; gig_done: boolean;
  decorated: boolean; wall: 'sage' | 'clay' | 'ocean';
  day: number; minutes: number; active: {code: Action; endsAt: number} | null; updatedAt: number;
  posts: Array<{id: string; title: string; budget: number; refunded: boolean; status: string}>; vote: string;
};
export type Intent = {revision: number; kind: 'sync' | 'greet' | 'begin' | 'decorate' | 'profile' | 'post' | 'cancel' | 'poll'; action?: Action; wall?: State['wall']; name?: string; bio?: string; title?: string; budget?: number; jobId?: string; choice?: string};
export class RuleError extends Error {
  constructor(public code: string, message: string, public status = 422) {super(message);}
}
export function initialState(now: number): State {
  return {name: 'New neighbor', bio: 'Finding my feet, one small win at a time.', coins: 240, food: 65, energy: 78, comfort: 70,
    repair: 0, digital: 0, social: 0, met_amaka: false, gig_done: false,
    decorated: false, wall: 'sage', day: 1, minutes: 480, posts: [], vote: '', active: null, updatedAt: now};
}
export function applyIntent(state: State, intent: Intent, now: number): Array<{delta: number; reason: string}> {
  const ledger: Array<{delta: number; reason: string}> = [];
  const elapsed = Math.max(0, Math.min(1200, (now - state.updatedAt) / 1000));
  state.minutes += elapsed * 0.8;
  state.day += Math.floor(state.minutes / 1440);
  state.minutes %= 1440;
  state.food = Math.max(0, state.food - elapsed * 0.025);
  state.energy = Math.max(0, state.energy - elapsed * 0.015);
  state.comfort = Math.max(0, state.comfort - elapsed * 0.01);
  if (state.active && state.active.endsAt <= now) {
    switch (state.active.code) {
      case 'learn': state.repair = Math.min(100, state.repair + 1); state.energy = Math.max(0, state.energy - 8); break;
      case 'study': state.digital = Math.min(100, state.digital + 1); state.energy = Math.max(0, state.energy - 8); break;
      case 'rest': state.energy = Math.min(100, state.energy + 35); break;
      case 'eat': state.food = Math.min(100, state.food + 35); state.energy = Math.min(100, state.energy + 4); break;
      case 'wash': state.comfort = Math.min(100, state.comfort + 20); break;
      case 'gig':
        if (!state.gig_done) {state.coins += 90; state.repair = Math.min(100, state.repair + 1); state.energy = Math.max(0, state.energy - 12); state.gig_done = true; ledger.push({delta: 90, reason: 'starter_gig'});}
        break;
    }
    state.active = null;
  }
  state.updatedAt = now;
  state.posts ??= []; state.vote ??= '';
  switch (intent.kind) {
    case 'sync': break;
    case 'greet':
      if (!state.met_amaka) {state.met_amaka = true; state.social++;}
      break;
    case 'begin': {
      if (!intent.action || !Object.hasOwn(actions, intent.action)) throw new RuleError('unknown_action', 'Choose a known activity.');
      const action = actions[intent.action];
      if (state.active) throw new RuleError('busy', 'Finish your current activity first.');
      if (intent.action === 'gig' && (state.repair < 1 || state.gig_done)) throw new RuleError('gig_locked', 'Practice Repair first; the starter gig pays once.');
      if (action.energy && state.energy < 15) throw new RuleError('low_energy', 'Rest at home until energy is at least 15.');
      if (state.coins < action.cost) throw new RuleError('insufficient_coins', 'You need more StreetCoins.');
      state.coins -= action.cost;
      if (action.cost) ledger.push({delta: -action.cost, reason: intent.action});
      state.active = {code: intent.action, endsAt: now + action.seconds * 1000};
      break;
    }
    case 'decorate':
      if (!intent.wall || !['sage', 'clay', 'ocean'].includes(intent.wall)) throw new RuleError('invalid_wall', 'Choose a listed home color.');
      state.wall = intent.wall; state.decorated = true; break;
    case 'profile':
      if (typeof intent.name !== 'string' || !intent.name.trim() || intent.name.trim().length > 30 || typeof intent.bio !== 'string' || intent.bio.length > 160) throw new RuleError('invalid_profile', 'Use a name up to 30 and a bio up to 160 characters.');
      state.name = intent.name.trim(); state.bio = intent.bio; break;
    case 'post': {
      if (!intent.title || intent.title.trim().length < 5 || intent.title.length > 60 || !Number.isInteger(intent.budget) || intent.budget! < 10 || intent.budget! > 10000) throw new RuleError('invalid_listing', 'Use a descriptive title and a budget of 10–10,000 SC.');
      if (state.posts.length >= 3) throw new RuleError('listing_limit', 'This build supports three private drafts.');
      const charge = 100 + intent.budget!;
      if (state.coins < charge) throw new RuleError('insufficient_coins', 'You need the 100 SC fee plus the reserved budget.');
      state.coins -= charge;
      state.posts.push({id: String(state.posts.length + 1), title: intent.title.trim(), budget: intent.budget!, refunded: false, status: 'Private draft'});
      ledger.push({delta: -charge, reason: 'private_draft'});
      break;
    }
    case 'cancel': {
      const post = state.posts.find(post => post.id === intent.jobId);
      if (!post || post.refunded) throw new RuleError('draft_unavailable', 'This draft is unavailable or already cancelled.');
      post.refunded = true; post.status = 'Cancelled'; state.coins += post.budget;
      ledger.push({delta: post.budget, reason: 'draft_budget_refund'}); break;
    }
    case 'poll':
      if (!intent.choice || !['A greener community square', 'Better evening street lighting', 'More benches at the bus stop'].includes(intent.choice)) throw new RuleError('invalid_choice', 'Select a listed practice-poll option.');
      state.vote = intent.choice; break;
  }
  return ledger;
}
