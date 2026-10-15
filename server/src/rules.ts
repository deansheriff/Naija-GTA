import {newRadioPuzzle, radioMatches, type RadioPuzzle} from './repair-puzzle.js';
import {freshCampaign, upgradeCampaign, campaignCommand, CampaignError, type Campaign} from './campaign.js';
export const actions = {
  learn: {seconds: 8, cost: 0, energy: 8},
  gig: {seconds: 10, cost: 0, energy: 12},
  eat: {seconds: 6, cost: 25, energy: 0},
  communitymeal: {seconds: 12, cost: 0, energy: 0},
  lantern: {seconds: 10, cost: 0, energy: 8},
  rest: {seconds: 8, cost: 0, energy: 0},
  wash: {seconds: 5, cost: 0, energy: 0},
  study: {seconds: 8, cost: 0, energy: 8},
  fan: {seconds: 20, cost: 0, energy: 18},
  inverter: {seconds: 30, cost: 0, energy: 26}
} as const;
export const repairJobs = {
  fan: {name: 'Service a standing fan', reward: 45, food: 8, skill: 2, completed: 0},
  inverter: {name: 'Diagnose an inverter', reward: 75, food: 12, skill: 4, completed: 3}
} as const;
export const homeItems = {rug: {name: 'Woven floor mat', price: 90}, plant: {name: 'Desk plant', price: 60}, radio: {name: 'Table radio', price: 180}} as const;
export const REPAIR_COOLDOWN = 45000;
export type Action = keyof typeof actions;
export type State = {
  campaign: Campaign;
  world_seed: number;
  name: string; bio: string; coins: number; food: number; energy: number; comfort: number;
  repair: number; digital: number; social: number; met_amaka: boolean; gig_done: boolean;
  decorated: boolean; wall: 'sage' | 'clay' | 'ocean';
  day: number; minutes: number; active: {code: Action; endsAt: number; puzzle?: RadioPuzzle} | null; updatedAt: number;
  posts: Array<{id: string; title: string; budget: number; refunded: boolean; status: string}>; vote: string;
  neighbors: {amaka: number; yemi: number; park: number; park_choice: string};
  favor: 'available' | 'carrying' | 'delivered' | 'complete';
  career: {completed: number; readyAt: number};
  inventory: {owned: string[]; equipped: string[]};
  errand: {stage: 'available' | 'collect' | 'repair' | 'ready' | 'installed' | 'complete'; spot: '' | 'board' | 'bench'};
};
export type Intent = {revision: number; kind: 'sync' | 'greet' | 'begin' | 'decorate' | 'profile' | 'post' | 'cancel' | 'poll' | 'neighbor' | 'buy' | 'furnish' | 'errand' | 'repair_move' | 'campaign_start' | 'campaign_choose' | 'campaign_pause' | 'campaign_resume' | 'campaign_switch' | 'campaign_continue' | 'campaign_drive' | 'campaign_phone' | 'campaign_review' | 'campaign_portfolio'; action?: Action; stage?: number; tile?: number; item?: string; wall?: State['wall']; name?: string; bio?: string; title?: string; budget?: number; jobId?: string; choice?: string};
export class RuleError extends Error {
  constructor(public code: string, message: string, public status = 422) {super(message);}
}
export function initialState(now: number): State {
  return {campaign: freshCampaign(), world_seed: 260713, name: 'New neighbor', bio: 'Finding my feet, one small win at a time.', coins: 240, food: 65, energy: 78, comfort: 70,
    repair: 0, digital: 0, social: 0, met_amaka: false, gig_done: false,
    decorated: false, wall: 'sage', day: 1, minutes: 480, posts: [], vote: '', active: null, updatedAt: now,
    neighbors: {amaka: 0, yemi: 0, park: 0, park_choice: ''}, favor: 'available',
    career: {completed: 0, readyAt: 0}, inventory: {owned: [], equipped: []}, errand: {stage: 'available', spot: ''}};
}
// Additive save upgrade: existing JSON characters keep their balances, receipts and schema.
export function upgradeState(state: State): State {
  state.campaign = upgradeCampaign(state.campaign ?? freshCampaign());
  state.world_seed ??= 260713;
  state.neighbors ??= {amaka: state.met_amaka ? 1 : 0, yemi: 0, park: 0, park_choice: ''};
  state.favor ??= 'available';
  state.career ??= {completed: 0, readyAt: 0};
  state.inventory ??= {owned: [], equipped: []};
  state.errand ??= {stage: 'available', spot: ''};
  return state;
}
function finishStarterGig(state: State, ledger: Array<{delta: number; reason: string}>) {
  if (!state.gig_done) {
    state.coins += 90; state.repair = Math.min(100, state.repair + 1);
    state.energy = Math.max(0, state.energy - 12); state.gig_done = true;
    ledger.push({delta: 90, reason: 'starter_gig'});
  }
}
export function applyIntent(state: State, intent: Intent, now: number): Array<{delta: number; reason: string}> {
  upgradeState(state);
  const storyCommand = intent.kind.startsWith('campaign_');
  const storyActive = state.campaign.status !== 'unstarted' && !state.campaign.paused;
  // Story never ages sandbox needs or settles an unrelated job. Keep its
  // remaining duration by shifting the deadline across the paused interval.
  if (storyCommand || storyActive) {
    const paused = Math.max(0, now - state.updatedAt);
    if (state.active) state.active.endsAt += paused;
    if (state.career.readyAt > state.updatedAt) state.career.readyAt += paused;
    state.updatedAt = now;
    if (storyCommand) {
      try {campaignCommand(state.campaign, intent.kind, intent.stage, intent.choice, now);}
      catch (error) {if (error instanceof CampaignError) throw new RuleError('campaign_choice', error.message); throw error;}
    } else if (intent.kind !== 'sync') throw new RuleError('campaign_active', 'Pause the campaign before continuing street activities.');
    return [];
  }
  const ledger: Array<{delta: number; reason: string}> = [];
  const elapsed = Math.max(0, Math.min(1200, (now - state.updatedAt) / 1000));
  state.minutes += elapsed * 0.8;
  state.day += Math.floor(state.minutes / 1440);
  state.minutes %= 1440;
  state.food = Math.max(0, state.food - elapsed * 0.025);
  state.energy = Math.max(0, state.energy - elapsed * 0.015);
  state.comfort = Math.max(0, state.comfort - elapsed * 0.01);
  if (state.active && state.active.endsAt <= now && (!state.active.puzzle || radioMatches(state.active.puzzle))) {
    switch (state.active.code) {
      case 'learn': state.repair = Math.min(100, state.repair + 1); state.energy = Math.max(0, state.energy - 8); break;
      case 'study': state.digital = Math.min(100, state.digital + 1); state.energy = Math.max(0, state.energy - 8); break;
      case 'rest': state.energy = Math.min(100, state.energy + 35); break;
      case 'eat': state.food = Math.min(100, state.food + 35); state.energy = Math.min(100, state.energy + 4); break;
      case 'communitymeal': state.food = Math.min(100, state.food + 25); break;
      case 'lantern':
        if (state.errand.stage === 'repair') {state.errand.stage = 'ready'; state.energy = Math.max(0, state.energy - 8);}
        break;
      case 'wash': state.comfort = Math.min(100, state.comfort + 20); break;
      case 'fan': case 'inverter': {
        const job = repairJobs[state.active.code];
        state.coins += job.reward;
        state.repair = Math.min(100, state.repair + 1);
        state.career.completed++;
        state.career.readyAt = state.active.endsAt + REPAIR_COOLDOWN;
        ledger.push({delta: job.reward, reason: 'repair_' + state.active.code});
        break;
      }
      case 'gig':
        finishStarterGig(state, ledger);
        break;
    }
    state.active = null;
  }
  state.updatedAt = now;
  state.posts ??= []; state.vote ??= '';
  switch (intent.kind) {
    case 'sync': break;
    case 'repair_move': {
      const active = state.active;
      if (!active || active.code !== 'gig' || !active.puzzle) throw new RuleError('repair_unavailable', 'Start Yemi\'s radio test before turning a dial.');
      if (!Number.isInteger(intent.tile) || intent.tile! < 0 || intent.tile! > 5) throw new RuleError('invalid_dial', 'Choose a radio channel from A to F.');
      if (radioMatches(active.puzzle)) throw new RuleError('repair_solved', 'All channels match. The radio test is finishing.');
      active.puzzle.turns[intent.tile!] = (active.puzzle.turns[intent.tile!] + 1) % 4;
      active.puzzle.solved = radioMatches(active.puzzle);
      if (active.puzzle.solved && active.endsAt <= now) {finishStarterGig(state, ledger); state.active = null;}
      break;
    }
    case 'errand': {
      const quest = state.errand;
      const locked = () => {throw new RuleError('errand_locked', 'Follow the current objective in A light for the square.');};
      switch (intent.choice) {
        case 'accept':
          if (quest.stage !== 'available' || !state.met_amaka || !state.gig_done) locked();
          quest.stage = 'collect'; break;
        case 'collect':
          if (quest.stage !== 'collect') locked();
          quest.stage = 'repair'; state.neighbors.park = Math.max(1, state.neighbors.park); break;
        case 'install_board': case 'install_bench':
          if (quest.stage !== 'ready') locked();
          quest.stage = 'installed'; quest.spot = intent.choice === 'install_board' ? 'board' : 'bench';
          state.neighbors.park = Math.max(2, state.neighbors.park); break;
        case 'finish':
          if (quest.stage !== 'installed') locked();
          quest.stage = 'complete'; state.coins += 40; state.social = Math.min(100, state.social + 1);
          state.neighbors.amaka = Math.max(2, state.neighbors.amaka); state.neighbors.yemi = Math.max(2, state.neighbors.yemi); state.neighbors.park = 3;
          ledger.push({delta: 40, reason: 'square_lantern_errand'}); break;
        default: throw new RuleError('invalid_errand_choice', 'Choose a listed lantern errand action.');
      }
      break;
    }
    case 'greet':
      if (!state.met_amaka) {state.met_amaka = true; state.social++;}
      state.neighbors.amaka = Math.max(1, state.neighbors.amaka);
      break;
    case 'neighbor': {
      switch (intent.choice) {
        case 'yemi_hello':
          if (!state.neighbors.yemi) {state.neighbors.yemi = 1; state.social = Math.min(100, state.social + 1);} break;
        case 'park_welcome':
          if (!state.neighbors.park) {state.neighbors.park = 1; state.social = Math.min(100, state.social + 1);}
          state.neighbors.park_choice = 'welcome'; break;
        case 'park_space': state.neighbors.park_choice = 'space'; break;
        case 'favor_accept':
          if (!state.met_amaka || state.favor !== 'available') throw new RuleError('favor_locked', 'Say hello to Amaka first. This favor can be accepted once.');
          state.favor = 'carrying'; break;
        case 'favor_deliver':
          if (state.favor !== 'carrying') throw new RuleError('favor_locked', 'Collect Amaka\'s covered lunch plate first.');
          state.favor = 'delivered'; state.neighbors.yemi = Math.max(2, state.neighbors.yemi); break;
        case 'favor_finish':
          if (state.favor !== 'delivered') throw new RuleError('favor_locked', 'Take the plate to Yemi, then return to Amaka.');
          state.favor = 'complete'; state.neighbors.amaka = 3; state.neighbors.yemi = 3;
          state.social = Math.min(100, state.social + 1); state.coins += 30;
          ledger.push({delta: 30, reason: 'neighbor_lunch_favor'}); break;
        default: throw new RuleError('invalid_neighbor_choice', 'Choose a listed neighbor conversation.');
      }
      break;
    }
    case 'begin': {
      if (!intent.action || !Object.hasOwn(actions, intent.action)) throw new RuleError('unknown_action', 'Choose a known activity.');
      const action = actions[intent.action];
      if (state.active) throw new RuleError('busy', 'Finish your current activity first.');
      if (intent.action === 'lantern' && (state.errand.stage !== 'repair' || state.repair < 1)) throw new RuleError('lantern_locked', 'Collect the park lantern and bring it to the repair bench first.');
      if (intent.action === 'communitymeal' && (state.coins >= 25 || state.food >= 20)) throw new RuleError('meal_reserved', 'Community plates are for neighbors below 20 food with fewer than 25 SC.');
      if (intent.action === 'gig' && (state.repair < 1 || state.gig_done)) throw new RuleError('gig_locked', 'Practice Repair first; the starter gig pays once.');
      if (intent.action === 'fan' || intent.action === 'inverter') {
        const job = repairJobs[intent.action];
        if (!state.gig_done || state.repair < job.skill || state.career.completed < job.completed) throw new RuleError('career_locked', 'Finish the starter radio repair and meet the listed skill and job requirements.');
        if (now < state.career.readyAt) throw new RuleError('career_cooldown', 'The next customer is on the way. Rest or eat, then check the job board again.');
        if (state.energy < action.energy + 5 || state.food < 20) throw new RuleError('career_needs', 'Eat until food is at least 20 and rest until energy covers the job plus 5.');
        // Charge needs on acceptance. Completion pays only the server-defined reward.
        state.energy -= action.energy; state.food -= job.food;
      }
      if (action.energy && intent.action !== 'fan' && intent.action !== 'inverter' && state.energy < 15) throw new RuleError('low_energy', 'Rest at home until energy is at least 15.');
      if (state.coins < action.cost) throw new RuleError('insufficient_coins', 'You need more StreetCoins.');
      state.coins -= action.cost;
      if (action.cost) ledger.push({delta: -action.cost, reason: intent.action});
      state.active = {code: intent.action, endsAt: now + action.seconds * 1000};
      if (intent.action === 'gig') state.active.puzzle = newRadioPuzzle();
      break;
    }
    case 'buy': case 'furnish': {
      if (!intent.item || !Object.hasOwn(homeItems, intent.item)) throw new RuleError('unknown_item', 'Choose an item from the home catalogue.');
      const item = intent.item as keyof typeof homeItems;
      if (intent.kind === 'buy') {
        if (state.inventory.owned.includes(item)) throw new RuleError('already_owned', 'You already own this item. Place it from your inventory.');
        const price = homeItems[item].price;
        if (state.coins < price) throw new RuleError('insufficient_coins', 'You need more StreetCoins.');
        state.coins -= price; state.inventory.owned.push(item); state.inventory.equipped.push(item);
        ledger.push({delta: -price, reason: 'home_' + item});
      } else {
        if (!state.inventory.owned.includes(item)) throw new RuleError('item_not_owned', 'Buy this item before placing it.');
        if (!['place', 'store'].includes(intent.choice ?? '')) throw new RuleError('invalid_furnishing', 'Choose place or store.');
        state.inventory.equipped = state.inventory.equipped.filter(id => id !== item);
        if (intent.choice === 'place') state.inventory.equipped.push(item);
      }
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
