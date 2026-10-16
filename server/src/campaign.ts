import story from './prologue.json' with {type:'json'};
import tunde from './tunde-intro.json' with {type:'json'};
import ngozi from './ngozi-intro.json' with {type:'json'};
import kc from './kc-intro.json' with {type:'json'};
import meeting from './family-meeting.json' with {type:'json'};
import generator from './generator-wars.json' with {type:'json'};
import interview from './japa-interview.json' with {type:'json'};
import chase from './danfo-chase.json' with {type:'json'};
import infiltration from './aso-ebi-infiltration.json' with {type:'json'};
import receipts from './small-small-receipts.json' with {type:'json'};
import viral from './viral.json' with {type:'json'};
import {freshViral,advanceViral,viralInputs,type ViralState,type ViralPhase} from './viral-task.js';
import {hasWitnessConsent} from './receipt-task.js';
import fuelQueue from './fuel-queue-standoff.json' with {type:'json'};
import {freshQueue,advanceQueue,queueInputs,type QueueState} from './queue-task.js';
import {freshReceipt,advanceReceipt,receiptInputs,witnessTextHash,type ReceiptState,type WitnessConsent} from './receipt-task.js';
import {freshPortfolio,advancePortfolio,portfolioInputs,type PortfolioState} from './portfolio-task.js';
import {journalAvailable,restoreEarnedRecords,earnedRecords} from './evidence-journal.js';
import {freshPhone,resetFrame,advancePhone,phoneInputs,type PhoneState} from './phone-task.js';
import {freshDrive,advanceDrive,driveInputs,type DrivingState,type DriveGate} from './driving-task.js';
export const prologue=story;
export const leads=['tunde','ngozi','kc'] as const;
export type Lead=typeof leads[number];
export type StoryChoice={id:string;label:string;correct:boolean;hint?:string;requiresWitnessConsent?:boolean;requiresChoice?:{id:string;value:string}};
export type StoryStage={id:string;lead:string;scene:string;title:string;text:string;summary:string;kind?:string;queuePhase?:string;viralPhase?:string;publicationPreview?:boolean;target?:number;driveGate?:DriveGate;recordCost?:number;subjects?:string[];requiresEvidence?:string[];effect?:string;previousChoice?:string;portfolioResponse?:boolean;responses?:Partial<Record<string,{text:string;summary:string}>>;records?:{title:string;lines:string[]}[];choices:StoryChoice[]};
export type Mission={id:string;title:string;summary:string;stages:StoryStage[];mastery:Partial<Record<Lead,number>>;evidence:string[]};
export const missions:Record<string,Mission>={P00:{...story,mastery:{tunde:1,ngozi:1,kc:1},evidence:['wedding_clip']},A11:tunde,A12:ngozi,A13:kc,A14:meeting,A21:generator,A22:interview,A23:chase,A24:infiltration,A25:receipts,A26:fuelQueue,A27:viral};
export const missionOrder=['P00','A11','A12','A13','A14','A21','A22','A23','A24','A25','A26','A27'];
export const CAMPAIGN_VERSION=12;
export type Campaign={version:number;mission:string;status:'unstarted'|'playing'|'hub';stage:number;lead:Lead;completed:string[];mastery:Record<Lead,number>;evidence:string[];paused:boolean;choices:Record<string,string>;drive:DrivingState|null;phone:PhoneState|null;portfolio:PortfolioState|null;receipt?:ReceiptState|null;witnessConsent?:WitnessConsent|null;queueTask?:QueueState|null;viral?:ViralState|null};
export class CampaignError extends Error {}
export function freshCampaign():Campaign{return {version:CAMPAIGN_VERSION,mission:'P00',status:'unstarted',stage:0,lead:'tunde',completed:[],mastery:{tunde:0,ngozi:0,kc:0},evidence:[],paused:true,choices:{},drive:null,phone:null,portfolio:null};}
export function upgradeCampaign(value:Campaign):Campaign {
  if(value.version===1)return {...freshCampaign(),...value,version:CAMPAIGN_VERSION,mission:'P00',choices:{},drive:null,phone:null};
  if(value.version===2||value.version===3)return {...value,version:CAMPAIGN_VERSION,phone:null,portfolio:null};
  if(value.version===4||value.version===5||value.version===6)return {...value,version:CAMPAIGN_VERSION,portfolio:null};
  if(value.version===7||value.version===8||value.version===9||value.version===10||value.version===11)return {...value,version:CAMPAIGN_VERSION};
  return value;
}
export function campaignCommand(c:Campaign,command:string,stage?:number,choice?:string,now=Date.now()):void {
  const mission=missions[c.mission];
  if(c.version!==CAMPAIGN_VERSION||!mission)throw new CampaignError('This campaign needs a newer game client. Its saved progress has been preserved.');
  const startStage=()=>{
    const task=missions[c.mission].stages[c.stage];
    c.lead=task.lead as Lead;
    c.drive=task.kind==='drive'?freshDrive(now):null;
    if(task.driveGate&&c.drive)c.drive.gateCleared=false;
    if(c.mission==='A13'){c.phone??=freshPhone();if(task.kind==='frame')resetFrame(c.phone);}
    if(c.mission==='A22')c.portfolio??=freshPortfolio();
    if(c.mission==='A25'){c.receipt??=freshReceipt();c.witnessConsent??=null;}
    if(c.mission==='A27')c.viral??=freshViral();
    if(c.mission==='A26'){
      c.queueTask??=freshQueue();
      if(task.queuePhase==='reset')c.queueTask.hint='';
    }
  };
  if(command==='campaign_start'){
    if(c.status!=='unstarted')throw new CampaignError('Your campaign has already started. Resume its checkpoint.');
    c.status='playing';c.paused=false;startStage();return;
  }
  if(c.status==='unstarted')throw new CampaignError('Start the wedding introduction first.');
  if(command==='campaign_pause'||command==='campaign_resume'){c.paused=command==='campaign_pause';if(c.drive)c.drive.lastAt=now;return;}
  if(command==='campaign_withdraw'){
    if(!c.completed.includes('A25'))throw new CampaignError('The witness review is not available yet.');
    c.witnessConsent=null;c.evidence=c.evidence.filter(id=>id!=='witness_consent');c.choices['A27-withdrawn']='yes';return;
  }
  if(command==='campaign_review'){
    if(!journalAvailable(c))throw new CampaignError('The evidence journal opens at Family Meeting.');
    restoreEarnedRecords(c);return;
  }
  if(command==='campaign_switch'){
    if(c.status!=='hub')throw new CampaignError('This mission has a staged perspective. Finish or pause this task first.');
    if(!leads.includes(choice as Lead))throw new CampaignError('Choose Tunde, Ngozi or KC.');
    c.lead=choice as Lead;return;
  }
  if(command==='campaign_continue'){
    if(c.status!=='hub'||c.paused)throw new CampaignError('Resume the completed mission hub first.');
    const next=missionOrder[missionOrder.indexOf(c.mission)+1];
    if(!next)throw new CampaignError('The next chapter is still in production. Your checkpoint is saved.');
    c.mission=next;c.stage=0;c.status='playing';startStage();return;
  }
  if(c.status!=='playing'||c.paused||stage!==c.stage)throw new CampaignError('This choice does not match your active campaign checkpoint. Reopen the story.');
  const task=mission.stages[c.stage];
  if(command==='campaign_publish'){
    if(task.kind!=='viral'||!c.viral||!viralInputs(task.viralPhase as ViralPhase).includes(choice!))throw new CampaignError('Use a listed source or correction control for this checkpoint.');
    advanceViral(c.viral,choice!,task.viralPhase as ViralPhase);return;
  }
  if(command==='campaign_queue'){
    if(task.kind!=='queue'||!c.queueTask||!queueInputs(task.queuePhase!).includes(choice!))throw new CampaignError('Use a listed queue control for this checkpoint.');
    advanceQueue(c.queueTask,choice!,task.queuePhase!);return;
  }
  if(command==='campaign_compare'){
    if(task.kind!=='receipt'||!c.receipt||!receiptInputs.includes(choice!))throw new CampaignError('Use a listed source-comparison control for this checkpoint.');
    advanceReceipt(c.receipt,choice!);return;
  }
  if(command==='campaign_portfolio'){
    if(task.kind!=='portfolio'||!c.portfolio||!portfolioInputs.includes(choice!))throw new CampaignError('Use one of the portfolio controls shown for this checkpoint.');
    advancePortfolio(c.portfolio,choice!);return;
  }
  if(command==='campaign_phone'){
    if(task.kind!=='frame'||!c.phone||!phoneInputs.includes(choice as typeof phoneInputs[number]))throw new CampaignError('Use the illustrated phone controls shown for this checkpoint.');
    advancePhone(c.phone,choice!,task.recordCost!);return;
  }
  if(command==='campaign_drive'){
    if(task.kind!=='drive'||!c.drive||!driveInputs.includes(choice as typeof driveInputs[number])||(choice==='yield'&&!task.driveGate))throw new CampaignError('Use the driving controls shown for this road leg.');
    advanceDrive(c.drive,choice!,now,task.target!,task.driveGate);return;
  }
  if(command!=='campaign_choose')throw new CampaignError('Choose a supported story action.');
  if(task.kind==='drive'&&(!c.drive?.ready||(task.driveGate&&!c.drive.gateCleared)))throw new CampaignError('Reach the lower-lane safe bay and stop first. Guided approach is available.');
  if(task.kind==='frame'&&!c.phone?.ready)throw new CampaignError('Save the full centred wide frame first. Guided full frame is available at the same battery cost.');
  if(task.kind==='portfolio'&&!c.portfolio?.ready)throw new CampaignError('Check the three portfolio answers first. Free practice, callback and guided answers are available.');
  if(task.kind==='receipt'&&!c.receipt?.ready)throw new CampaignError('Check all three source comparisons first. Guided matching is free.');
  if(task.kind==='queue'&&!(task.queuePhase==='line'?c.queueTask?.lineReady:c.queueTask?.resetReady))throw new CampaignError('Check the current queue task first. Free guidance is available.');
  if(task.kind==='viral'&&!c.viral?.[task.viralPhase as ViralPhase].ready)throw new CampaignError('Check this source or correction board first. Free guidance is available.');
  const selected=task.choices.find(option=>option.id===choice);
  if(!selected)throw new CampaignError('Choose one of the options shown for this task.');
  if(selected.requiresWitnessConsent&&!hasWitnessConsent(c))throw new CampaignError('Current exact-text permission is unavailable. Use the anonymised document route.');
  if(selected.requiresChoice&&c.choices[selected.requiresChoice.id]!==selected.requiresChoice.value)throw new CampaignError('The saved witness boundary does not permit this review. Use the anonymised-record route.');
  if(!selected.correct)throw new CampaignError(selected.hint??'Try the labelled objective again.');
  if(task.requiresEvidence?.some(id=>!c.evidence.includes(id)))throw new CampaignError('A source record is missing. Open the evidence journal and choose Restore earned records.');
  if(task.effect==='publication_permission'&&choice==='withdraw'){c.witnessConsent=null;c.evidence=c.evidence.filter(id=>id!=='witness_consent');c.choices['A27-withdrawn']='yes';}
  if(task.effect==='witness_review')c.witnessConsent=choice==='approve_ne1'?{textHash:witnessTextHash,scope:'redacted_text',active:true}:null;
  if(task.effect==='charge_phone'&&c.phone)c.phone.battery=4;
  c.choices[c.mission+'-'+task.id]=choice!;c.stage++;
  if(c.stage===mission.stages.length){
    c.status='hub';c.drive=null;
    if(!c.completed.includes(c.mission)){
      c.completed.push(c.mission);
      for(const lead of leads)c.mastery[lead]=Math.min(100,c.mastery[lead]+(mission.mastery[lead]??0));
      c.evidence=[...new Set([...c.evidence,...mission.evidence])];
      for(const id of earnedRecords(c,c.mission))if(!c.evidence.includes(id))c.evidence.push(id);
    }
  }else startStage();
}
