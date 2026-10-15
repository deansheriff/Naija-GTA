import {test} from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {Store} from '../src/store.js';
import {createApp} from '../src/app.js';
import {CAMPAIGN_VERSION,missionOrder} from '../src/campaign.js';
import {campaignCommands} from '../src/capabilities.js';
test('public world capabilities describe actual story support without mutating settings or saves',async()=>{
  const dir=mkdtempSync(join(tmpdir(),'nsl-capabilities-')),store=new Store(join(dir,'save.sqlite')),app=createApp(store);
  try{
    const before=await store.ops.settings(),r=await app.inject({url:'/api/v1/world'});assert.equal(r.statusCode,200);assert.equal(r.headers['cache-control'],'no-store');
    const body=r.json();assert.deepEqual(body.settings,before);assert.deepEqual(body.capabilities,{api:1,campaignVersion:CAMPAIGN_VERSION,campaignMissions:missionOrder,campaignCommands});
    assert.deepEqual(await store.ops.settings(),before);assert.equal(store.db.prepare('SELECT COUNT(*) AS count FROM characters').get()!.count,0);
    assert.equal((await app.inject({url:'/api/health'})).statusCode,200);
  }finally{await app.close();rmSync(dir,{recursive:true,force:true});}
});
