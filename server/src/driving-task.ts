import chase from './chase-driving.json' with {type:'json'};
export const chaseDrivingData=chase;
export type DriveGate={at:number;kind:string};
export type DrivingState = {distance: number; speed: number; lane: number; lastAt: number; ready: boolean; misses: number; hint: string;gateCleared?:boolean};
export const driveInputs = ['accelerate','brake','coast','upper','lower','assist','yield'] as const;
export function freshDrive(now: number): DrivingState {return {distance:0,speed:0,lane:1,lastAt:now,ready:false,misses:0,hint:''};}
export function advanceDrive(drive: DrivingState, input: string, now: number, target: number,gate?:DriveGate): void {
  const dt=Math.max(0,Math.min(1,(now-drive.lastAt)/1000));drive.lastAt=now;
  if(drive.ready)return;
  const waiting=!!gate&&!drive.gateCleared,goal=waiting?gate!.at:target;
  if(input==='yield'){
    if(!waiting)return;
    if(drive.distance>=goal-30&&drive.distance<=goal&&drive.speed<=2&&drive.lane===1){drive.gateCleared=true;drive.hint=chase.messages.cleared;}
    else drive.hint=chase.messages.wrongWait;
    return;
  }
  if(input==='upper')drive.lane=0;
  if(input==='lower')drive.lane=1;
  const previous=drive.speed;
  if(input==='assist') {
    drive.lane=1;drive.distance=Math.min(goal,drive.distance+50*dt);drive.speed=drive.distance>=goal?0:50;
  } else {
    drive.speed=Math.max(0,Math.min(70,drive.speed+(input==='accelerate'?30:input==='brake'?-60:-10)*dt));
    drive.distance+=(previous+drive.speed)*0.5*dt;
  }
  if(drive.distance>goal+(waiting?0:90)) {
    const misses=drive.misses+1;Object.assign(drive,freshDrive(now),{misses,hint:waiting?chase.messages.loop:'Missed the bay. Take the free loop; start braking earlier, or use Guided approach.'});if(gate)drive.gateCleared=false;return;
  }
  drive.ready=!waiting&&drive.distance>=target-40&&drive.speed<=2&&drive.lane===1;
  if(waiting&&drive.distance>=goal-30&&drive.speed<=2&&drive.lane===1)drive.hint=chase.messages.stop;
  if(drive.ready)drive.hint='Safe stop. Read the passenger cue and choose your next move.';
}
