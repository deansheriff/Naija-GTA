import data from './portfolio-task.json' with {type:'json'};
export const portfolioData=data;
export type PortfolioState={answers:Record<string,string>;attempts:number;ready:boolean;needsRecovery:boolean;route:'first'|'practice'|'callback';hint:string};
export const portfolioInputs=[...data.questions.flatMap(q=>q.options.map(o=>q.id+':'+o.id)),...data.actions.map(a=>a.id)];
export function freshPortfolio():PortfolioState{return {answers:{},attempts:0,ready:false,needsRecovery:false,route:'first',hint:''};}
export function advancePortfolio(p:PortfolioState,input:string):void{
  if(p.ready)return;
  if(input==='practice'||input==='callback'){
    if(!p.needsRecovery){p.hint=data.messages.no_recovery;return;}
    p.needsRecovery=false;p.route=input;p.hint=data.messages[input];return;
  }
  if(p.needsRecovery){p.hint=data.messages.recover_first;return;}
  if(input==='assist'){
    for(const q of data.questions)p.answers[q.id]=q.options.find(o=>o.correct)!.id;
    p.hint=data.messages.guided;return;
  }
  if(input==='present'){
    p.attempts=Math.min(100000,p.attempts+1);
    p.ready=data.questions.every(q=>q.options.some(o=>o.correct&&o.id===p.answers[q.id]));
    p.needsRecovery=!p.ready;p.hint=p.ready?data.messages.ready:data.messages.correction;return;
  }
  const [id,choice]=input.split(':');
  if(data.questions.some(q=>q.id===id&&q.options.some(o=>o.id===choice))){p.answers[id]=choice;p.hint=data.messages.selected;}
}
