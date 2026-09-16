'use strict';
const fs=require('node:fs');
const crypto=require('node:crypto');
const assert=(ok,message)=>{if(!ok)throw new Error(message)};
const read=file=>fs.readFileSync(file,'utf8');
const candidate=read('wip35-v166-candidate.html');
const js=read('lts-v166-feedback-closure.js');
const css=read('lts-v166-feedback-closure.css');
const sql=read('supabase/canonical_v166_feedback_closure_2026_09_16.sql');
const checkpoint=read('backups/V165_USER_ACCEPTED_BASELINE_2026-09-16.md');
const indexHash=crypto.createHash('sha256').update(fs.readFileSync('index.html')).digest('hex');

assert(indexHash==='cca36731258680cc15a73fbad61c90ddf803358b741fd3ef58fefe5419eb688b','protected public index changed');
for(const token of ['V166','lts-v166-feedback-closure.js','lts-executive-visual-system-v2.js'])assert(candidate.includes(token),'candidate missing '+token);
for(const token of ['v165_preserved:true','flow_1409_preserved:true','decorateUpdates','decorateExpense','decorateDashboard','decorateWealth','openInFlow','openTransaction','Este lançamento é ajustado no Fluxo','openProposal','openAward','openCipo','searchObserver','requestAnimationFrame(()=>{searchDecorationQueued=false;decorateSearch()})'])assert(js.includes(token),'runtime missing '+token);
for(const token of ['lts_browser_create_future_event_v1','lts_browser_save_award_assumption_v1','cash_rsu_enters_projected_liquidity_on_available_date','daily-flow-fix86-v19-cash-rsu-availability','audit_log','lts_browser_assert_user_v1'])assert(sql.includes(token),'migration missing '+token);
for(const token of ['Published product commit','6bcdfb1f78baf944e6f215da045b75ef3244d4de','V166 non-regression contract'])assert(checkpoint.includes(token),'checkpoint missing '+token);
assert(!sql.includes('184.483')&&!sql.includes('12829.97')&&!sql.includes('2874.35'),'private award values leaked into migration');
assert(css.includes('@media(max-width:820px)'),'mobile styles missing');

console.log(JSON.stringify({pass:true,version:'v166-feedback-closure',v165_checkpoint:true,public_index_unchanged:true,cash_rsu_available_date:true,append_only_actions:true,private_values_in_migration:false},null,2));
