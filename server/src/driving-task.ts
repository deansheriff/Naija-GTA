export type DrivingState = {distance: number; speed: number; lane: number; lastAt: number; ready: boolean; misses: number; hint: string};
export const driveInputs = ['accelerate','brake','coast','upper','lower','assist'] as const;
export function freshDrive(now: number): DrivingState {return {distance:0,speed:0,lane:1,lastAt:now,ready:false,misses:0,hint:''};}
export function advanceDrive(drive: DrivingState, input: string, now: number, target: number): void {
  const dt=Math.max(0,Math.min(1,(now-drive.lastAt)/1000));drive.lastAt=now;
  if(drive.ready)return;
  if(input==='upper')drive.lane=0;
  if(input==='lower')drive.lane=1;
  const previous=drive.speed;
  if(input==='assist') {
    drive.lane=1;drive.distance=Math.min(target,drive.distance+50*dt);drive.speed=drive.distance>=target?0:50;
  } else {
    drive.speed=Math.max(0,Math.min(70,drive.speed+(input==='accelerate'?30:input==='brake'?-60:-10)*dt));
    drive.distance+=(previous+drive.speed)*0.5*dt;
  }
  if(drive.distance>target+90) {
    const misses=drive.misses+1;Object.assign(drive,freshDrive(now),{misses,hint:'Missed the bay. Take the free loop; start braking earlier, or use Guided approach.'});return;
  }
  drive.ready=drive.distance>=target-40&&drive.speed<=2&&drive.lane===1;
  if(drive.ready)drive.hint='Safe stop. Read the passenger cue and choose your next move.';
}
