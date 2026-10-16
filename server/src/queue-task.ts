import data from './queue-task.json' with {type:'json'};
export const queueData=data;
export type QueueState={order:string[];duplicateResolved:boolean;lineReady:boolean;bucketUpright:boolean;aisleClear:boolean;resetReady:boolean;checks:number;hint:string};
export const queueInputs=(phase:string)=>phase==='line'?[...data.parties.flatMap(p=>['earlier:'+p.id,'later:'+p.id]),...data.lineActions.map(a=>a.id)]:data.resetActions.map(a=>a.id);
export function freshQueue():QueueState{return {order:[...data.initialOrder],duplicateResolved:false,lineReady:false,bucketUpright:false,aisleClear:false,resetReady:false,checks:0,hint:''};}
export function advanceQueue(q:QueueState,input:string,phase:string):void{
  if(phase==='line'){
    if(q.lineReady)return;
    if(input==='check'){q.checks=Math.min(100000,q.checks+1);q.lineReady=q.duplicateResolved&&q.order.every((id,i)=>id===data.order[i]);q.hint=q.lineReady?data.messages.lineReady:data.messages.lineCorrection;return;}
    if(input==='assist'){q.order=[...data.order];q.duplicateResolved=true;q.hint=data.messages.guided;return;}
    if(input==='verify'){q.duplicateResolved=true;q.hint=data.messages.verified;return;}
    const [direction,id]=input.split(':'),index=q.order.indexOf(id),next=index+(direction==='earlier'?-1:1);
    if(index<0||next<0||next>=q.order.length){q.hint=data.messages.edge;return;}
    [q.order[index],q.order[next]]=[q.order[next],q.order[index]];q.hint=data.messages.moved;return;
  }
  if(q.resetReady)return;
  if(input==='check'){q.checks=Math.min(100000,q.checks+1);q.resetReady=q.bucketUpright&&q.aisleClear;q.hint=q.resetReady?data.messages.resetReady:data.messages.resetCorrection;return;}
  if(input==='assist'){q.bucketUpright=true;q.aisleClear=true;q.hint=data.messages.resetGuided;return;}
  if(input==='bucket'){q.bucketUpright=true;q.hint=data.messages.bucket;return;}
  if(input==='aisle'){if(!q.bucketUpright){q.hint=data.messages.bucketFirst;return;}q.aisleClear=true;q.hint=data.messages.aisle;}
}
