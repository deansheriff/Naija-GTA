import data from './receipt-task.json' with {type:'json'};
import {createHash} from 'node:crypto';
export const receiptData=data;
export const witnessTextHash=createHash('sha256').update(data.witnessText).digest('hex');
export type ReceiptState={answers:Record<string,string>;attempts:number;ready:boolean;hint:string};
export type WitnessConsent={textHash:string;scope:'redacted_text';active:boolean};
export function hasWitnessConsent(c:{choices:Record<string,string>;witnessConsent?:WitnessConsent|null}):boolean{return c.choices['A24-consent']==='redacted_review'&&c.choices['A25-public_review']==='approve_ne1'&&c.witnessConsent?.active===true&&c.witnessConsent.scope==='redacted_text'&&c.witnessConsent.textHash===witnessTextHash;}
export const receiptInputs=[...data.questions.flatMap(q=>q.options.map(o=>q.id+':'+o.id)),...data.actions.map(a=>a.id)];
export function freshReceipt():ReceiptState{return {answers:{},attempts:0,ready:false,hint:''};}
export function advanceReceipt(task:ReceiptState,input:string):void{
  if(task.ready)return;
  if(input==='assist'){for(const q of data.questions)task.answers[q.id]=q.options.find(o=>o.correct)!.id;task.hint=data.messages.guided;return;}
  if(input==='check'){
    task.attempts=Math.min(100000,task.attempts+1);task.ready=data.questions.every(q=>q.options.some(o=>o.correct&&task.answers[q.id]===o.id));task.hint=task.ready?data.messages.ready:data.messages.correction;return;
  }
  const [id,choice]=input.split(':');if(data.questions.some(q=>q.id===id&&q.options.some(o=>o.id===choice))){task.answers[id]=choice;task.hint=data.messages.selected;}
}
