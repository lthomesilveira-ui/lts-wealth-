"""Reject drift of the inlined predecessor without changing the isolated fixture."""
import json
import subprocess
from pathlib import Path

root = Path(__file__).resolve().parents[3]
patch = (root / 'backend/patches/v406/single_assembly_export.sql').read_text()
guard = patch.split('CREATE OR REPLACE FUNCTION', 1)[0]

for name, signature in [
    ('lts_backup_modern_export_v380', '(uuid)'),
    ('lts_backup_modern_export_pre_v403', '(uuid)'),
    ('lts_backup_family_extend_v398', '(uuid,jsonb)'),
    ('lts_backup_position_sources_v403', '(uuid)'),
    ('lts_backup_base_schema_v406', '()'),
]:
    sql = f"""BEGIN;
DO $drift$
DECLARE definition text:=pg_get_functiondef('public.{name}{signature}'::regprocedure);
BEGIN
 EXECUTE replace(definition,'AS $function$',E'AS $function$\\n-- synthetic predecessor drift');
END $drift$;
{guard}
ROLLBACK;
"""
    result = subprocess.run(['psql', '-XAtq', '-v', 'ON_ERROR_STOP=1'], input=sql,
                            text=True, capture_output=True)
    assert result.returncode != 0, name + ': drift was accepted'
    assert 'Backup predecessor changed: ' + name in result.stderr, result.stderr
print(json.dumps({'predecessor_drift_rejections': 5, 'drift_transactions_rolled_back': True}))
