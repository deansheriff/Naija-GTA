export type PhoneState={battery:number;pan:number;zoom:number;ready:boolean;takes:number;charges:number;hint:string};
export const phoneInputs=['left','right','wide','detail','record','assist','charge'] as const;
export function freshPhone():PhoneState{return {battery:4,pan:0,zoom:2,ready:false,takes:0,charges:0,hint:''};}
export function resetFrame(phone:PhoneState):void{Object.assign(phone,{pan:0,zoom:2,ready:false,hint:''});}
export function advancePhone(phone:PhoneState,input:string,cost:number):void{
  if(phone.ready)return;
  if(input==='charge'){
    if(phone.battery===0){phone.battery=4;phone.charges++;phone.hint='Borrowed enough charge for another try. The original footage is safe.';}
    else phone.hint='There is charge left. Adjust the frame and try the take.';
    return;
  }
  if(input==='left')phone.pan=Math.max(0,phone.pan-1);
  if(input==='right')phone.pan=Math.min(2,phone.pan+1);
  if(input==='wide')phone.zoom=1;
  if(input==='detail')phone.zoom=2;
  if(input!=='record'&&input!=='assist'){phone.hint='Frame the three labelled subjects together. Panning uses no battery.';return;}
  if(phone.battery<cost){phone.hint='Battery empty. Borrow enough charge; no original footage is lost.';return;}
  if(input==='assist'){phone.pan=1;phone.zoom=1;}
  phone.battery-=cost;phone.takes++;
  phone.ready=phone.pan===1&&phone.zoom===1;
  phone.hint=phone.ready?'Full frame saved. Continue below.':phone.battery===0?'Battery empty. Borrow enough charge; no original footage is lost.':'The crop misses context. Centre the camera and use Wide, or choose Guided full frame.';
}
