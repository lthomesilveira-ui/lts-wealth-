"""Build a disposable synthetic PostgreSQL fixture from public repository sources."""
from pathlib import Path
import json,re

ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).parent
SOURCES={
 'lts_flow_dynamic_layers_v1':'backend/patches/v290/automatic_market_quotes.sql',
 'lts_daily_flow_fix86_v19':'backend/patches/v290/automatic_market_quotes.sql',
 'lts_daily_flow_fix86_v20':'backend/patches/v290/automatic_market_quotes.sql',
 'lts_dashboard_cash_ladder_from_flow_v229':'backend/patches/v399/materialized_liquidity_ladder.sql',
 'lts_dashboard_cash_ladder_from_flow_v2':'backend/patches/cofrinho_movement_identity_v245.sql',
 'lts_flow_morgan_available_overlay_v1':'supabase/migrations/20260917110325_v170_v169_user_review.sql',
 'lts_browser_wealth_detail_v2':'backend/patches/v290/automatic_market_quotes.sql',
 'lts_browser_wealth_detail_v3':'backend/patches/v290/automatic_market_quotes.sql',
 'lts_browser_wealth_detail_v4':'backend/patches/v290/automatic_market_quotes.sql',
 'provenance_v183':'backend/patches/v290/automatic_market_quotes.sql',
 'lts_browser_save_award_assumption_v1':'supabase/canonical_v166_feedback_closure_2026_09_16.sql',
 'lts_browser_save_all_award_assumptions_v1':'supabase/migrations/20260917110325_v170_v169_user_review.sql',
 'lts_browser_save_vesting_anticipation_v1':'supabase/canonical_v165_private_awards_and_search_2026_09_16.sql',
 'lts_cashflow_scenarios_v1':'backend/patches/v290/automatic_market_quotes.sql',
 'lts_cashflow_scenarios_v2':'backend/patches/v290/automatic_market_quotes.sql',
 'lts_cashflow_scenarios_from_flow_v1':'backend/patches/v290/automatic_market_quotes.sql',
 'lts_dashboard_executive_v2':'backend/patches/v290/automatic_market_quotes.sql',
}

def extract(name,path):
 text=(ROOT/path).read_text()
 match=re.search(r'(?i)CREATE\s+(?:OR\s+REPLACE\s+)?FUNCTION\s+(?:\w+\.)?'+re.escape(name)+r'\s*\(',text)
 if not match:raise ValueError(name)
 text=text[match.start():]
 marker=re.search(r'(?i)\bAS\s+(\$\w*\$)',text)
 end=text.find(marker.group(1),marker.end())
 if end<0:raise ValueError('Unclosed public source: '+name)
 text=text[:end+len(marker.group(1))]+';\n'
 # Reproduce already public V259/V386 patches, without a live baseline copy.
 if name=='lts_dashboard_cash_ladder_from_flow_v2':
  text=text.replace("lock_key='morgan_available_20260922' and superseded_at is null",
   "lock_key LIKE 'morgan_available_%' and superseded_at is null AND (canonical_value->>'as_of')::date<=current_date ORDER BY (canonical_value->>'as_of')::date DESC,lock_key DESC LIMIT 1")
 if name=='lts_browser_wealth_detail_v3':
  text=text.replace('return v_base||jsonb_build_object(',"-- v386-fgts-position-evidence: remove the excluded audio placeholder.\n  return (v_base-'schiavalli')||jsonb_build_object(")
  text=text.replace("'schiavalli',jsonb_build_object('status','documentary_position_not_located','included_in_total',false)","'fgts_position',public.lts_fgts_position_evidence_v386(v_uid,current_date)")
 return text

def build():
 parts=[(HERE/'fixture.sql').read_text()]
 for name,path in SOURCES.items():parts.append(extract(name,path))
 v290=(ROOT/'backend/patches/v290/automatic_market_quotes.sql').read_text()
 start=v290.index('CREATE VIEW public.lts_future_liquidity_effective_v290')
 end=v290.index('-- Source leases',start)
 parts.append(v290[start:end])
 parts.append((HERE/'qa_helpers.sql').read_text())
 parts.append((HERE/'seed.sql').read_text())
 return '\n'.join(parts)

if __name__=='__main__':print(build())
