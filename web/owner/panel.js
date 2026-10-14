'use strict';
const $ = id => document.getElementById(id);
let csrfToken = '', settings, playersCursor = '', auditCursor = '', pendingReview;
const message = (text, error = false) => {const box = $('message'); box.textContent = text; box.classList.toggle('error', error); box.hidden = !text;};
const el = (tag, text, cls) => {const node = document.createElement(tag); if (text !== undefined) node.textContent = text; if (cls) node.className = cls; return node;};
async function api(path, method = 'GET', body) {
  const response = await fetch('/api/owner' + path, {method, credentials: 'same-origin', headers: {'Content-Type':'application/json', 'X-CSRF-Token':csrfToken}, ...(body ? {body:JSON.stringify(body)} : {})});
  const result = await response.json();
  if (response.status === 401) signedOut();
  if (!response.ok) throw new Error(response.status === 404 ? 'Owner access is not enabled. Configure OWNER_USERNAME, OWNER_PASSWORD_HASH and PUBLIC_ORIGIN in Coolify.' : result.message || 'Request failed. Refresh and try again.');
  return result;
}
const run = fn => async event => {event?.preventDefault(); try {await fn(event);} catch (error) {message(error.message, true);}};
function signedOut() {csrfToken = ''; settings = undefined; pendingReview = undefined; $('review').close(); $('login').hidden = false; $('workspace').hidden = true; $('logout').hidden = true; $('identity').textContent = 'Private owner access'; $('password').value = ''; for(const id of ['players-body','player-detail','audit-body','stats','runtime','published-notice','world-status'])$(id).replaceChildren();}
async function signedIn(session) {csrfToken = session.csrfToken; $('identity').textContent = session.username + ' · Owner'; $('login').hidden = true; $('workspace').hidden = false; $('logout').hidden = false; $('password').value = ''; message(''); await view('overview');}
async function view(name) {
  for (const section of ['overview','players','settings','audit']) $('view-' + section).hidden = section !== name;
  document.querySelectorAll('nav [data-view]').forEach(button => {if (button.dataset.view === name) button.setAttribute('aria-current', 'page'); else button.removeAttribute('aria-current');});
  if (name === 'overview') await overview();
  if (name === 'players') await players();
  if (name === 'settings') await loadSettings();
  if (name === 'audit') await audit();
  $('main').focus({preventScroll:true}); window.scrollTo({top:0});
}
document.querySelectorAll('[data-view]').forEach(button => button.addEventListener('click', run(() => view(button.dataset.view))));
$('login-form').addEventListener('submit', run(async () => {
  const button = $('login-form').querySelector('button'); button.disabled = true;
  try {await signedIn(await api('/login','POST',{username:$('username').value,password:$('password').value}));} finally {button.disabled = false; $('password').value = '';}
}));
$('logout').addEventListener('click', run(async () => {await api('/logout','POST',{}); signedOut(); message('You have signed out.');}));
function tag(text, warn) {return el('span',text, 'tag' + (warn ? ' warn' : ''));}
async function overview() {
  const data = await api('/overview'); settings = data.settings;
  $('updated').textContent = 'Last checked ' + new Date(data.serverTime).toLocaleString();
  $('stats').replaceChildren(...[['Saved characters',data.counts.characters],['Stored sessions',data.counts.sessions],['Saved command receipts',data.counts.commands],['Currency ledger entries',data.counts.ledger]].map(([label,value]) => {const card=el('article',undefined,'stat');card.append(el('span',label),el('b',Number(value).toLocaleString()));return card;}));
  $('published-notice').textContent = settings.announcement || 'No street announcement. A fresh day awaits.';
  $('world-status').replaceChildren(tag(settings.maintenance ? 'Activities paused' : 'Activities open',settings.maintenance),tag(settings.favorEnabled ? 'Lunch favor open' : 'New lunch favors paused',!settings.favorEnabled),tag('Content revision ' + settings.revision));
  $('runtime').replaceChildren(...[['Database','Connected'],['Process uptime',Math.floor(data.runtime.uptimeSeconds / 60) + ' minutes'],['Requests / rate limited',data.runtime.requests + ' / ' + data.runtime.rateLimited],['Server errors',data.runtime.serverErrors],['Receipt retention',data.retention.receiptsDays + ' days']].map(([key,value])=>{const row=el('div');row.append(el('dt',key),el('dd',value));return row;}));
}
$('refresh-overview').addEventListener('click',run(overview));
async function players(after = '') {
  const data = await api('/players' + (after ? '?after=' + encodeURIComponent(after) : '')); playersCursor = data.next;
  $('players-body').replaceChildren(...data.players.map(player => {const row=el('tr'), who=el('td',player.name);who.append(el('small',player.id));const action=el('td'),button=el('button','Inspect →');button.addEventListener('click',run(()=>inspect(player.id)));action.append(button);row.append(who,el('td',Number(player.coins).toLocaleString()),el('td',player.suspended ? 'Suspended' : 'Open'),action);return row;}));
  if (!data.players.length) {const row=el('tr'), cell=el('td','No saved characters yet. Enter the game to start a story.');cell.colSpan=4;row.append(cell);$('players-body').append(row);}
  $('next-players').hidden = !playersCursor;
}
$('refresh-players').addEventListener('click',run(()=>players())); $('next-players').addEventListener('click',run(()=>players(playersCursor)));
$('find-player').addEventListener('submit',run(()=>inspect($('player-id').value.trim())));
async function inspect(id) {
  const data=await api('/players/'+encodeURIComponent(id)), panel=$('player-detail'); panel.hidden=false;
  panel.replaceChildren(el('span','PLAYER SAVE · REVISION '+data.character.revision,'eyebrow'),el('h2',data.character.state.name),el('p',id),el('p',(data.suspended?'Suspended':'Access open')+' · '+data.sessions+' unexpired sessions'));
  const actions=el('div',undefined,'actions');
  for (const [action,label] of [[data.suspended?'resume':'suspend',data.suspended?'Resume save access':'Suspend save access'],['revoke_sessions','Sign out all devices']]) {
    const button=el('button',label,action==='resume'?'':'danger');
    button.addEventListener('click',()=>review(label,label+' for '+data.character.state.name+' ('+id+'). Progress and currency are retained. Revoked devices can reconnect with a valid save access code.',async reason=>{await api('/players/'+id+'/access','POST',{action,reason});await inspect(id);await players();}));actions.append(button);
  }
  panel.append(actions,el('h3','Saved progress'),el('pre',JSON.stringify(data.character.state,null,2)),el('h3','Recent currency ledger'));
  const list=el('dl');for(const entry of data.ledger){const row=el('div');row.append(el('dt',entry.reason+' · '+new Date(Number(entry.created_at)).toLocaleString()),el('dd',(Number(entry.delta)>0?'+':'')+entry.delta+' SC · balance '+entry.balance));list.append(row);}panel.append(list);panel.scrollIntoView({behavior:'smooth',block:'start'});
}
async function loadSettings() {settings=(await api('/overview')).settings; for(const key of ['announcement','amakaLine','yemiLine','newCharacterSeed'])$(key).value=settings[key];for(const key of ['maintenance','favorEnabled'])$(key).checked=settings[key];$('settings-revision').textContent='Revision '+settings.revision;}
$('reload-settings').addEventListener('click',run(loadSettings));
$('settings-form').addEventListener('submit',run(async()=>{
  const value={revision:settings.revision,announcement:$('announcement').value,amakaLine:$('amakaLine').value,yemiLine:$('yemiLine').value,newCharacterSeed:Number($('newCharacterSeed').value),maintenance:$('maintenance').checked,favorEnabled:$('favorEnabled').checked};
  review('Publish street settings','Activities: '+(value.maintenance?'paused':'open')+'. New lunch favors: '+(value.favorEnabled?'open':'paused')+'. New character seed: '+value.newCharacterSeed+'. Announcement: '+(value.announcement||'(none)'),async reason=>{await api('/settings','PUT',{settings:value,reason});await loadSettings();});
}));
function review(title,body,action){pendingReview=action;$('review-title').textContent=title;$('review-body').textContent=body;$('reason').value='';$('review').showModal();$('reason').focus();}
$('cancel-review').addEventListener('click',()=>{$('review').close();pendingReview=undefined;});
$('review-form').addEventListener('submit',run(async()=>{
  if(!pendingReview)return;const button=$('review-form').querySelector('.primary');button.disabled=true;
  try{await pendingReview($('reason').value.trim());$('review').close();pendingReview=undefined;message('Change saved. The audit trail has been updated.');}finally{button.disabled=false;}
}));
async function audit(before=''){
  const data=await api('/audit'+(before?'?before='+before:''));auditCursor=data.next;
  $('audit-body').replaceChildren(...data.events.map(event=>{const row=el('tr'),who=el('td',new Date(Number(event.created_at)).toLocaleString());who.append(el('small',event.actor));const target=el('td',event.reason);target.append(el('small',event.target||'—'));row.append(who,el('td',event.action),target);return row;}));$('next-audit').hidden=!auditCursor;
}
$('refresh-audit').addEventListener('click',run(()=>audit()));$('next-audit').addEventListener('click',run(()=>audit(auditCursor)));
api('/session').then(signedIn).catch(error=>{signedOut();if(!error.message.includes('Sign in as the owner.'))message(error.message,true);});
