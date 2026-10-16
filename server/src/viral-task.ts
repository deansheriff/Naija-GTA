import data from './viral-task.json' with {type:'json'};
import {hasWitnessConsent,receiptData,type ReceiptState} from './receipt-task.js';
export const viralData=data;
export type ViralPhase='rumour'|'correction';
export type ViralState={rumour:ReceiptState;correction:ReceiptState};
export function freshViral():ViralState {const task=():ReceiptState=>({answers:{},attempts:0,ready:false,hint:''});return {rumour:task(),correction:task()};}
export function viralInputs(phase:ViralPhase):string[]{const board=data[phase];return [...board.questions.flatMap(q=>q.options.map(o=>q.id+':'+o.id)),...board.actions.map(a=>a.id)];}
export function advanceViral(v:ViralState,input:string,phase:ViralPhase):void{
 const task=v[phase],board=data[phase];if(task.ready)return;
 if(input==='assist'){for(const q of board.questions)task.answers[q.id]=q.options.find(o=>o.correct)!.id;task.hint=board.messages.guided;return;}
 if(input==='check'){task.attempts=Math.min(100000,task.attempts+1);task.ready=board.questions.every(q=>q.options.some(o=>o.correct&&task.answers[q.id]===o.id));task.hint=task.ready?board.messages.ready:board.messages.correction;return;}
 const [id,choice]=input.split(':');if(board.questions.some(q=>q.id===id&&q.options.some(o=>o.id===choice))){task.answers[id]=choice;task.hint=board.messages.selected;}
}
type PublicationCampaign={choices:Record<string,string>;witnessConsent?:Parameters<typeof hasWitnessConsent>[0]['witnessConsent']};
export function publication(c:PublicationCampaign){
 const witness=c.choices['A27-route']==='witness'&&c.choices['A27-permission']==='retain'&&hasWitnessConsent(c);
 return {route:witness?'witness':'documents',disclosure:data.disclosure,scope:witness?data.status.witness:c.choices['A27-permission']==='withdraw'||c.choices['A27-withdrawn']==='yes'?data.status.withdrawn:data.status.documents,lines:witness?[receiptData.witnessText]:[...data.documents]};
}
