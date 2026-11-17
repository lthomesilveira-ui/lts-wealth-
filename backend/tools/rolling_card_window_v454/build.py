"""A dated card provision may start at a rolling number of calendar months ahead."""
import argparse
import hashlib
import json
import re
import shutil
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
CALC = 'lts_projection_private_v412.calculate(jsonb,jsonb,jsonb,date)'
PROVISION = 'lts_projection_private_v412.card_new_spend_provision(jsonb,date)'
PROFILE = 'lts_product_refresh_private_v415.review_profile_v450()'

def original(name):
    return (HERE / name).read_text()

def md5(value):
    return hashlib.md5(value.encode()).hexdigest()

def once(text, old, new):
    assert text.count(old) == 1, old[:100]
    return text.replace(old, new)

def provision():
    return once(original('provision-original.sql'),
        " starts:=(c->>'starts_on')::date;amount:=(c->>'amount_brl')::numeric;",
        """ IF c ? 'lead_months' THEN
  IF jsonb_typeof(c->'lead_months') IS DISTINCT FROM 'number'
   OR coalesce(c->>'lead_months','') !~ '^[0-9]{1,2}$' THEN
   RAISE EXCEPTION 'Confira a antecedência da provisão do cartão.';END IF;
  IF (c->>'lead_months')::integer NOT BETWEEN 0 AND 12 THEN
   RAISE EXCEPTION 'Confira a antecedência da provisão do cartão.';END IF;
 END IF;
 starts:=(c->>'starts_on')::date;amount:=(c->>'amount_brl')::numeric;""")

def calculate():
    text = once(original('calculate-original.sql'),
        "DECLARE provision jsonb; provision_now jsonb;",
        "DECLARE provision_start date; lead_months integer; provision jsonb; provision_now jsonb;")
    text = once(text,
        "  provision_now:=lts_projection_private_v412.card_new_spend_provision(r,p_as_of);",
        """  provision_now:=lts_projection_private_v412.card_new_spend_provision(r,p_as_of);
  lead_months:=NULL;provision_start:=NULL;
  IF r#>'{new_spend_provision,lead_months}' IS NOT NULL THEN
   -- Validate the entire provision even before its original start date.
   PERFORM lts_projection_private_v412.card_new_spend_provision(r,NULL);
   lead_months:=(r#>>'{new_spend_provision,lead_months}')::integer;
   provision_start:=greatest((r#>>'{new_spend_provision,starts_on}')::date,
    (date_trunc('month',p_as_of::timestamp)+make_interval(months=>lead_months))::date);
   provision_now:=r->'new_spend_provision';
  END IF;""")
    text = once(text,
        "   provision:=lts_projection_private_v412.card_new_spend_provision(r,effective_date);",
        """   IF provision_start IS NOT NULL AND effective_date<provision_start THEN
    -- Near months contain only obligations already retained in the base flow.
    -- No historical allowance, new provision or replacement event is emitted.
    skipped:=skipped+1;
    results:=results||jsonb_build_array(jsonb_build_object('event_date',effective_date,
     'budget_total_brl',known,'additional_brl',0,'known_amount_brl',known,
     'basis','rolling_window_known_only'));
    CONTINUE;
   END IF;
   provision:=lts_projection_private_v412.card_new_spend_provision(r,effective_date);""")
    return once(text,
        "(r->'new_spend_provision')-'preserved_legacy_obligations'",
        "((r->'new_spend_provision')-'preserved_legacy_obligations')||CASE WHEN provision_start IS NOT NULL THEN jsonb_build_object('starts_on',provision_start) ELSE '{}'::jsonb END")

def profile():
    source = original('profile-original.sql')
    match = re.search(r'\$manifest\$([\s\S]*?)\$manifest\$', source)
    data = json.loads(match[1])
    for signature, before, after in [(CALC, original('calculate-original.sql'), calculate()),
                                    (PROVISION, original('provision-original.sql'), provision())]:
        entries = [x for x in data['producers'] if x['signature'] == signature]
        assert len(entries) == 1 and entries[0]['md5'] == md5(before)
        entries[0]['md5'] = md5(after)
    return source[:match.start(1)] + json.dumps(data, indent=2) + '\n' + source[match.end(1):]

def targets():
    return [(PROVISION, 'provision-original.sql', provision()),
            (CALC, 'calculate-original.sql', calculate()),
            (PROFILE, 'profile-original.sql', profile())]

def lifecycle(reverse=False):
    checks, changes = [], []
    for signature, name, candidate in targets():
        before, after = (candidate, original(name)) if reverse else (original(name), candidate)
        checks.append(f"""p:='{signature}'::regprocedure;
 SELECT md5(pg_get_functiondef(p)),to_jsonb(f)-'prosrc' INTO h,a FROM pg_proc f WHERE oid=p;
 IF h NOT IN('{md5(before)}','{md5(after)}') OR a->>'proacl' IS DISTINCT FROM '["postgres=X/postgres", "service_role=X/postgres"]'
 OR a->>'proconfig' IS DISTINCT FROM '["search_path=\\"\\""]' OR (a->>'prosecdef')::boolean
 OR (SELECT pg_get_userbyid(proowner) FROM pg_proc WHERE oid=p)<>'postgres' THEN
 RAISE EXCEPTION 'Rolling card window predecessor changed: %',p;END IF;""")
        changes.append(f"""p:='{signature}'::regprocedure;
 IF md5(pg_get_functiondef(p))='{md5(before)}' THEN
  SELECT to_jsonb(f)-'prosrc' INTO a FROM pg_proc f WHERE oid=p;
  EXECUTE $replacement${after}$replacement$;
  IF md5(pg_get_functiondef(p))<>'{md5(after)}' OR a IS DISTINCT FROM(SELECT to_jsonb(f)-'prosrc' FROM pg_proc f WHERE oid=p) THEN
   RAISE EXCEPTION 'Rolling card window definition or attributes differ';END IF;
  changed:=true;
 END IF;""")
    return "BEGIN;\nSET LOCAL lock_timeout='2s';\nDO $lifecycle$ DECLARE p regprocedure;h text;a jsonb;changed boolean:=false;BEGIN\n" + '\n'.join(checks + changes) + "\nIF changed THEN UPDATE public.lts_read_cache_epoch_v242 SET epoch=epoch+1 WHERE singleton;END IF;\nEND $lifecycle$;\nCOMMIT;\n"

def release(target):
    base = ROOT / 'releases/v451'
    shutil.copytree(base, target)
    app = target / 'app.html'
    assert app.read_text().count('V451') == 5
    app.write_text(app.read_text().replace('V451', 'V454'))
    changed = {}
    def edit(name, old, new):
        changed.setdefault(name, (base/name).read_text())
        (target/name).write_text(once((target/name).read_text(), old, new))
    name = 'lts-v412-projection-policy.js'
    edit(name,
        "          provision = { startsOn, amount: provisionAmount, active: asOf >= startsOn };",
        """          const leadMonths = value.lead_months === undefined ? null : value.lead_months;
          if (leadMonths !== null && (!Number.isInteger(leadMonths) || leadMonths < 0 || leadMonths > 12)) return invalid();
          provision = { startsOn, amount: provisionAmount, active: asOf >= startsOn,
            ...(leadMonths !== null ? { leadMonths, rolling: true } : {}) };""")
    edit(name, "if (!provision?.active && (row.method", "if (!provision?.active && !provision?.rolling && (row.method")
    edit(name, "usesHistory: !provision?.active && (row.uses_history", "usesHistory: !provision?.active && !provision?.rolling && (row.uses_history")
    edit(name,
        "      return 'Novos gastos: ' + money(provision.amount) + '/mês a partir de ' + date(provision.startsOn) + ', além das parcelas.';",
        """      if (provision.rolling) return 'Novos gastos: ' + money(provision.amount) + '/mês desde o ' + provision.leadMonths + 'º mês à frente, além das parcelas conhecidas. Neste cálculo: a partir de ' + date(provision.startsOn) + '.';
      return 'Novos gastos: ' + money(provision.amount) + '/mês a partir de ' + date(provision.startsOn) + ', além das parcelas.';""")
    edit(name, "if (row.newSpendProvision?.active) return provisionText(row);", "if (row.newSpendProvision?.active || row.newSpendProvision?.rolling) return provisionText(row);")
    edit(name, "row.amount !== null && !row.newSpendProvision?.active", "row.amount !== null && !row.newSpendProvision?.active && !row.newSpendProvision?.rolling")
    edit(name, "row.newSpendProvision && !row.newSpendProvision.active", "row.newSpendProvision && !row.newSpendProvision.active && !row.newSpendProvision.rolling")
    edit('lts-v441-flow-summary.js',
        'Novos gastos: R$ 15 mil por mês somente no Aeternum a partir de fevereiro de 2027, além das parcelas existentes.',
        'Novos gastos: R$ 15 mil por mês somente no Aeternum, desde o terceiro mês à frente. A janela avança a cada mês; antes dela entram apenas faturas e parcelas conhecidas.')
    edit('lts-v423-clarity-model.js',
        "return names[key]?{title:names[key]+' · complemento do orçamento',note:'Previsão adicional; não é outra fatura.'}:null;",
        "return names[key]?{title:names[key]+(key==='card_aeternum'?' · novos gastos previstos':' · complemento do orçamento'),note:key==='card_aeternum'?'Novas compras previstas.':'Previsão adicional; não é outra fatura.'}:null;")
    for name, old in changed.items():
        bundles = [target / n for n in ['lts-v384-startup-1.js','lts-v384-startup-2.js'] if old in (target/n).read_text()]
        if bundles:
            assert len(bundles) == 1
            bundles[0].write_text(once(bundles[0].read_text(), old, (target/name).read_text()))
    sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
    (target/'provenance.json').write_text(json.dumps({'release':'v454','base_release':'v451',
        'scope':'Rolling card new-spend window; existing obligations retained',
        'raw_financial_writers_changed':False,'authentication_changed':False,
        'physical_device_validated':False},indent=2)+'\n')
    (target/'manifest.json').write_text(json.dumps({'release':'v454','version':'v454','entry':'app.html','base_release':'v451',
        'protected_manifest':{'path':'releases/v451/manifest.json','sha256':sha(base/'manifest.json')},
        'files':{p.name:sha(p) for p in sorted(target.iterdir()) if p.name!='manifest.json'}},indent=2)+'\n')

def build(check=False):
    expected = {'provision.sql':provision(),'calculate.sql':calculate(),'profile.sql':profile(),
                'install.sql':lifecycle(),'rollback.sql':lifecycle(True),
                'manifest.json':json.dumps([{'signature':s,'before':md5(original(n)),'after':md5(c)} for s,n,c in targets()],indent=2)+'\n'}
    for name, content in expected.items():
        if check: assert (HERE/name).read_text() == content, name
        else: (HERE/name).write_text(content)
    with tempfile.TemporaryDirectory() as d:
        output = Path(d)/'v454';release(output);actual=ROOT/'releases/v454'
        if check: assert {p.name:p.read_bytes() for p in actual.iterdir()} == {p.name:p.read_bytes() for p in output.iterdir()}
        else:
            assert not actual.exists(), 'Never overwrite a published release'
            shutil.copytree(output, actual)
    print(json.dumps({'pass':True,'release':'v454','protected':'v451'}))

if __name__ == '__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--check',action='store_true')
    build(parser.parse_args().check)
