import data from './evidence-journal.json' with {type:'json'};
import type {Campaign} from './campaign.js';
import {hasWitnessConsent} from './receipt-task.js';
export const journalData=data;
export function journalAvailable(c:Campaign):boolean{return c.mission==='A14'||c.completed.includes('A14');}
export function earnedRecords(c:Campaign,mission?:string):string[]{return data.entries.filter(entry=>(!mission||entry.mission===mission)&&c.completed.includes(entry.mission)&&(!entry.requiresChoice||c.choices[entry.requiresChoice.id]===entry.requiresChoice.value)&&(!entry.requiresWitnessReview||hasWitnessConsent(c))).map(entry=>entry.id);}
export function restoreEarnedRecords(c:Campaign):void{for(const id of earnedRecords(c))if(!c.evidence.includes(id))c.evidence.push(id);}
export function journalStatus(c:Campaign){
  const admitted=c.choices['A27-correction']==='save_correction'||c.choices['A13-disclose']==='admit'||c.choices['A14-disclosure']==='tell';
  const disclosure=admitted?data.states.disclosure_admitted:c.choices['A13-disclose']==='defer'||c.choices['A14-disclosure']==='later'?data.states.disclosure_open:data.states.disclosure_none;
  const custody=c.choices['A14-custody']==='ngozi_record'?data.states.custody_ngozi_record:c.choices['A14-custody']==='joint_record'?data.states.custody_joint_record:data.states.custody_none;
  const pact=c.choices['A14-pact']==='protect'?data.states.pact_protect:c.choices['A14-pact']==='public_case'?data.states.pact_public_case:data.states.pact_none;
  return {disclosure,custody,pact};
}
