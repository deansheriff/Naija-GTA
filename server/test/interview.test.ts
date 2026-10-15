import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,mkdtempSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {Store} from '../src/store.js';
import {createApp} from '../src/app.js';
import {interviewContract,generatorHub} from './interview-contract.js';
import {upgradeCampaign,CAMPAIGN_VERSION,missions} from '../src/campaign.js';
import {freshPortfolio,advancePortfolio,portfolioData} from '../src/portfolio-task.js';
import {contentUnits} from '../src/content-review.js';
import type {Intent} from '../src/rules.js';
test('Japa Interview: three presentation routes, both pieces, recovery and once-only opportunity/mastery',async()=>{
  const dir=mkdtempSync(join(tmpdir(),'nsl-interview-')),file=join(dir,'save.sqlite');let now=1700000000000,store=new Store(file,()=>now),app=createApp(store);
  try{
    const ids=await interviewContract(app,ms=>{now+=ms;},async(id,c)=>{store.db.prepare("UPDATE characters SET state=json_set(state,'$.campaign',json(?)) WHERE id=?").run(JSON.stringify(c),id);});
    for(const id of ids)assert.equal(store.db.prepare('SELECT COUNT(*) AS total FROM ledger WHERE character_id=?').get(id)!.total,1);
    const guest=store.createGuest(),c=generatorHub();store.db.prepare("UPDATE characters SET state=json_set(state,'$.campaign',json(?)) WHERE id=?").run(JSON.stringify(c),guest.character.id);
    let revision=0;const send=(kind:Intent['kind'],stage?:number,choice?:string)=>store.execute(guest.character.id,`interview-restart-checkpoint-${revision}`,{kind,revision:revision++,stage,choice});
    send('campaign_continue');for(let i=0;i<4;i++)send('campaign_choose',i,missions.A22.stages[i].choices[0].id);
    send('campaign_portfolio',4,'role:everything');send('campaign_portfolio',4,'present');const before=store.read(guest.character.id).state.campaign;
    await app.close();store=new Store(file,()=>now);app=createApp(store);const restored=store.read(guest.character.id).state.campaign;
    assert.deepEqual(restored.portfolio,before.portfolio);assert.equal(restored.portfolio!.needsRecovery,true);assert.equal(restored.phone!.battery,0);assert.equal(restored.version,CAMPAIGN_VERSION);
    send('campaign_portfolio',4,'callback');send('campaign_portfolio',4,'assist');send('campaign_portfolio',4,'present');assert.equal(store.read(guest.character.id).state.campaign.portfolio!.route,'callback');
  }finally{await app.close();rmSync(dir,{recursive:true,force:true});}
});
test('portfolio consistency, recovery and ready-state bounds',()=>{
  for(let mask=0;mask<8;mask++){
    const p=freshPortfolio();portfolioData.questions.forEach((q,index)=>advancePortfolio(p,q.id+':'+q.options[(mask>>index)&1].id));advancePortfolio(p,'present');
    assert.equal(p.ready,mask===0);assert.equal(p.needsRecovery,mask!==0);assert.equal(p.attempts,1);
    if(mask){const answers=structuredClone(p.answers);advancePortfolio(p,'assist');assert.deepEqual(p.answers,answers);advancePortfolio(p,'practice');advancePortfolio(p,'assist');assert.equal(p.ready,false);advancePortfolio(p,'present');assert.equal(p.ready,true);assert.equal(p.route,'practice');}
    const copy=structuredClone(p);advancePortfolio(p,'present');advancePortfolio(p,'callback');assert.deepEqual(p,copy);
  }
  const bounded=freshPortfolio();bounded.attempts=100000;advancePortfolio(bounded,'present');assert.equal(bounded.attempts,100000);
});
test('interview canonical sources, owner-review coverage and version-6 upgrade',()=>{
  assert.deepEqual(JSON.parse(readFileSync(new URL('../../game/story/japa-interview.json',import.meta.url),'utf8')),missions.A22);
  assert.deepEqual(JSON.parse(readFileSync(new URL('../../game/story/portfolio-task.json',import.meta.url),'utf8')),portfolioData);
  const c=generatorHub();delete (c as any).portfolio;const old=structuredClone(c),updated=upgradeCampaign(c);assert.equal(updated.version,CAMPAIGN_VERSION);assert.equal(updated.portfolio,null);assert.deepEqual({...updated,version:6,portfolio:undefined},{...old,portfolio:undefined});assert.deepEqual(c,old);
  const board=contentUnits.find(u=>u.id==='portfolio-board')!;for(const q of portfolioData.questions)for(const option of q.options)assert.ok(board.text.includes(option.label));
  for(const text of [...Object.values(portfolioData.messages),...Object.values(portfolioData.routes)])assert.ok(board.text.includes(text));
  for(const stage of missions.A22.stages){const unit=contentUnits.find(u=>u.id==='A22-'+stage.id)!;assert.ok(unit&&stage.summary);for(const response of Object.values(stage.responses??{}))if(response)assert.ok(unit.text.includes(response.text));}
  assert.ok(contentUnits.find(u=>u.id==='journal-open_window')!.text.includes('not wedding evidence'));
});
