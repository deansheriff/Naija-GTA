import data from './promise-task.json' with {type:'json'};
import {advanceReceipt,freshReceipt,type ReceiptState} from './receipt-task.js';
export const promiseData=data;
export const promiseInputs=[...data.questions.flatMap(q=>q.options.map(o=>q.id+':'+o.id)),...data.actions.map(a=>a.id)];
export const freshPromise=freshReceipt;
export function advancePromise(task:ReceiptState,input:string):void{advanceReceipt(task,input,data);}
