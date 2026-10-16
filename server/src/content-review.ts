import {createHash} from 'node:crypto';
import {missions} from './campaign.js';
import street from './street-review.json' with {type: 'json'};
import {journalData} from './evidence-journal.js';
import {portfolioData} from './portfolio-task.js';
import {chaseDrivingData} from './driving-task.js';
import {receiptData} from './receipt-task.js';
import {queueData} from './queue-task.js';

export type ContentUnit = {id: string; context: string; text: string; choices: string[]; channel: 'campaign' | 'street'; hash: string};
export type ReviewRecord = {id: number; unit_id: string; content_hash: string; status: 'approved' | 'changes_requested' | 'pending'; notes: string; actor: string; created_at: number};
export type ReviewSubmission = {unitId: string; contentHash: string; revision: number; status: ReviewRecord['status']; notes: string};
const hash = (text: string) => createHash('sha256').update(text).digest('hex');
const units = [
  ...Object.values(missions).flatMap(mission => mission.stages.map(stage => ({id: mission.id + '-' + stage.id, context: `Up NEPA! / ${mission.title} / ${stage.lead} / ${stage.title}`, text: stage.text + '\n\nScene summary:\n' + stage.summary + (stage.records ? '\n\nTable records:\n' + stage.records.map(record => record.title + '\n' + record.lines.join('\n')).join('\n\n') : '') + (stage.subjects ? '\n\nFrame subjects:\n' + stage.subjects.join('\n') : '') + (stage.responses ? '\n\nRoute variations:\n' + Object.entries(stage.responses).flatMap(([id,response])=>response?[id+'\n'+response.text+'\nSummary: '+response.summary]:[]).join('\n\n') : ''), choices: stage.choices.map(choice => choice.label + (choice.hint ? '\nRetry hint: ' + choice.hint : '')), channel: 'campaign' as const}))),
  ...street.units.map(unit => ({...unit, channel: 'street' as const})),
  ...[...journalData.entries,...journalData.notes].map(entry=>({id:'journal-'+entry.id,context:'Up NEPA! / Evidence journal / '+entry.title,text:entry.kind+'\nSource: '+entry.source+'\n'+entry.scope,choices:[] as string[],channel:'campaign' as const})),
  {id:'journal-meeting-status',context:'Up NEPA! / Evidence journal / Meeting decisions',text:Object.values(journalData.states).join('\n\n'),choices:[] as string[],channel:'campaign' as const},
  {id:'portfolio-board',context:'Up NEPA! / Japa Interview / '+portfolioData.title,text:portfolioData.instructions+'\n\n'+portfolioData.questions.map(q=>q.title+'\n'+q.options.map(o=>o.label).join('\n')).join('\n\n')+'\n\n'+Object.values(portfolioData.messages).join('\n\n')+'\n\n'+Object.values(portfolioData.routes).join('\n'),choices:portfolioData.actions.map(a=>a.label),channel:'campaign' as const},
  {id:'chase-driving',context:'Up NEPA! / Danfo Chase / Marked route stops',text:chaseDrivingData.instructions+'\n\n'+Object.values(chaseDrivingData.messages).join('\n\n'),choices:[chaseDrivingData.waitLabel],channel:'campaign' as const},
  {id:'journal-account-permission',context:'Up NEPA! / Evidence journal / Account permission',text:Object.values(journalData.accountScopes).join('\n\n'),choices:[],channel:'campaign' as const},
  {id:'receipt-board',context:'Up NEPA! / Small Small Receipts / '+receiptData.title,text:receiptData.instructions+'\n\n'+receiptData.questions.map(q=>q.title+'\n'+q.options.map(o=>o.label).join('\n')).join('\n\n')+'\n\n'+Object.values(receiptData.messages).join('\n\n')+'\n\n'+receiptData.witnessText+'\n'+receiptData.witnessScope,choices:receiptData.actions.map(a=>a.label),channel:'campaign' as const},
  {id:'journal-witness-review',context:'Up NEPA! / Evidence journal / Current witness-text review',text:Object.values(journalData.reviewScopes).join('\n\n'),choices:[],channel:'campaign' as const},
  {id:'queue-board',context:'Up NEPA! / Fuel Queue Standoff / '+queueData.title,text:queueData.instructions+'\n'+queueData.resetInstructions+'\n\n'+queueData.parties.map(p=>p.label+' / '+p.arrival+' / '+p.ticket+('correctedTicket' in p?' / corrected '+p.correctedTicket:'')).join('\n')+'\n\n'+Object.values(queueData.messages).join('\n\n'),choices:[...queueData.lineActions,...queueData.resetActions].map(a=>a.label),channel:'campaign' as const}
];
export const contentUnits: ContentUnit[] = units.map(unit => ({...unit, hash: hash(JSON.stringify(unit))}));
export function reviewQueue(records: ReviewRecord[]) {
  const latest = new Map(records.map(record => [record.unit_id, record]));
  const queue = contentUnits.map(unit => {
    const review = latest.get(unit.id);
    return {...unit, revision: review?.id ?? 0, status: review?.content_hash === unit.hash ? review.status : 'pending', review: review ?? null, changedSinceReview: !!review && review.content_hash !== unit.hash};
  });
  return {units: queue, counts: {total: queue.length, approved: queue.filter(u => u.status === 'approved').length, changesRequested: queue.filter(u => u.status === 'changes_requested').length, pending: queue.filter(u => u.status === 'pending').length}, coverage: 'Current authored campaign chapters and generated park, named-neighbour, lantern and nearby street dialogue. Future chapters are added as they are built. A complete release also needs review of staging, art and remaining UI/content.'};
}
