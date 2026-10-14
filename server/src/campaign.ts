import story from './prologue.json' with {type: 'json'};
export const prologue = story;
export const leads = ['tunde', 'ngozi', 'kc'] as const;
export type Lead = typeof leads[number];
export type Campaign = {version: number; status: 'unstarted' | 'playing' | 'hub'; stage: number; lead: Lead; completed: string[]; mastery: Record<Lead, number>; evidence: string[]; paused: boolean};
export class CampaignError extends Error {}
export function freshCampaign(): Campaign {return {version: 1, status: 'unstarted', stage: 0, lead: 'tunde', completed: [], mastery: {tunde: 0, ngozi: 0, kc: 0}, evidence: [], paused: true};}
export function campaignCommand(c: Campaign, command: string, stage?: number, choice?: string): void {
  if (c.version !== 1) throw new CampaignError('This campaign needs a newer game client. Its saved progress has been preserved.');
  if (command === 'campaign_start') {
    if (c.status !== 'unstarted') throw new CampaignError('Your campaign has already started. Resume its checkpoint.');
    c.status = 'playing'; c.paused = false; return;
  }
  if (c.status === 'unstarted') throw new CampaignError('Start the wedding introduction first.');
  if (command === 'campaign_pause') {c.paused = true; return;}
  if (command === 'campaign_resume') {c.paused = false; return;}
  if (command === 'campaign_switch') {
    if (c.status !== 'hub') throw new CampaignError('The wedding has a staged perspective order. Finish or pause this task first.');
    if (!leads.includes(choice as Lead)) throw new CampaignError('Choose Tunde, Ngozi or KC.');
    c.lead = choice as Lead; return;
  }
  if (command !== 'campaign_choose' || c.status !== 'playing' || c.paused || stage !== c.stage) throw new CampaignError('This choice does not match your active campaign checkpoint. Reopen the story.');
  const task = prologue.stages[c.stage];
  const selected = task?.choices.find(option => option.id === choice);
  if (!selected) throw new CampaignError('Choose one of the options shown for this task.');
  if (!selected.correct) throw new CampaignError('hint' in selected ? String(selected.hint) : 'Try the labelled objective again.');
  c.stage++;
  if (c.stage === prologue.stages.length) {
    c.status = 'hub'; c.completed = ['P00']; c.mastery = {tunde: 1, ngozi: 1, kc: 1}; c.evidence = ['wedding_clip'];
  } else c.lead = prologue.stages[c.stage].lead as Lead;
}
