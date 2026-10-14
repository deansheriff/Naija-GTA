import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,mkdtempSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {createHash} from 'node:crypto';
import {Store} from '../src/store.js';
import {createApp} from '../src/app.js';
import {contentUnits} from '../src/content-review.js';
import {contentReviewContract} from './content-review-contract.js';
import {fixtureOwner} from './operations-contract.js';
import street from '../src/street-review.json' with {type:'json'};

test('admin content review: current-version decisions, concurrency, auth, history and restart',async()=>{
  const dir=mkdtempSync(join(tmpdir(),'nsl-review-')),file=join(dir,'save.sqlite');let store=new Store(file),app=createApp(store,{owner:fixtureOwner});
  try{
    const id=await contentReviewContract(store,app);
    assert.throws(()=>store.db.prepare("UPDATE content_reviews SET notes='changed'").run(),/append-only/);
    assert.throws(()=>store.db.prepare('DELETE FROM content_reviews').run(),/append-only/);
    const before=store.ops.contentHistory(id,Number.MAX_SAFE_INTEGER);
    await app.close();store=new Store(file);app=createApp(store,{owner:fixtureOwner});
    assert.deepEqual(store.ops.contentHistory(id,Number.MAX_SAFE_INTEGER),before);
    assert.equal((await store.ops.contentReviews()).length,1);
  }finally{await app.close();rmSync(dir,{recursive:true,force:true});}
});

test('review catalogue is distinct, bounded, and generated from current street source',()=>{
  assert.equal(new Set(contentUnits.map(u=>u.id)).size,contentUnits.length);
  for(const unit of contentUnits){assert.match(unit.id,/^[A-Za-z0-9._-]{1,100}$/);assert.match(unit.hash,/^[a-f0-9]{64}$/);assert.ok(unit.text.length&&unit.context.length);}
  for(const [file,expected] of Object.entries(street.sources)){
    const source=readFileSync(new URL('../../game/'+file,import.meta.url),'utf8').replaceAll('\r\n','\n');
    assert.equal(createHash('sha256').update(source).digest('hex'),expected,'Run scripts/build.ps1 to refresh the street review catalogue');
  }
});
