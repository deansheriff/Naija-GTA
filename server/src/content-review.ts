import {createHash} from 'node:crypto';
import {prologue} from './campaign.js';
import street from './street-review.json' with {type: 'json'};

export type ContentUnit = {id: string; context: string; text: string; choices: string[]; channel: 'campaign' | 'street'; hash: string};
export type ReviewRecord = {id: number; unit_id: string; content_hash: string; status: 'approved' | 'changes_requested' | 'pending'; notes: string; actor: string; created_at: number};
export type ReviewSubmission = {unitId: string; contentHash: string; revision: number; status: ReviewRecord['status']; notes: string};
const hash = (text: string) => createHash('sha256').update(text).digest('hex');
const units = [
  ...prologue.stages.map(stage => ({id: 'P00-' + stage.id, context: `Up NEPA! / Owambe, Owambe / ${stage.lead} / ${stage.title}`, text: stage.text + '\n\nScene summary:\n' + stage.summary, choices: stage.choices.map(choice => choice.label + ('hint' in choice ? '\nRetry hint: ' + choice.hint : '')), channel: 'campaign' as const})),
  ...street.units.map(unit => ({...unit, channel: 'street' as const}))
];
export const contentUnits: ContentUnit[] = units.map(unit => ({...unit, hash: hash(JSON.stringify(unit))}));
export function reviewQueue(records: ReviewRecord[]) {
  const latest = new Map(records.map(record => [record.unit_id, record]));
  const queue = contentUnits.map(unit => {
    const review = latest.get(unit.id);
    return {...unit, revision: review?.id ?? 0, status: review?.content_hash === unit.hash ? review.status : 'pending', review: review ?? null, changedSinceReview: !!review && review.content_hash !== unit.hash};
  });
  return {units: queue, counts: {total: queue.length, approved: queue.filter(u => u.status === 'approved').length, changesRequested: queue.filter(u => u.status === 'changes_requested').length, pending: queue.filter(u => u.status === 'pending').length}, coverage: 'Current wedding introduction and generated park, named-neighbour, lantern and nearby street dialogue. Future chapters are added as they are built. A complete release also needs review of staging, art and remaining UI/content.'};
}
