#!/usr/bin/env python3
"""Transparent diagnostics for synthetic SQL only; no SQL or result rewriting."""
import pathlib,subprocess,sys
ROOT=pathlib.Path(__file__).resolve().parent
payload=sys.stdin.buffer.read()
(ROOT/'psql-input.sql').write_bytes(payload)
result=subprocess.run(['/usr/bin/psql',*sys.argv[1:]],input=payload,capture_output=True,check=False)
(ROOT/'psql-stdout.log').write_bytes(result.stdout)
(ROOT/'psql-stderr.log').write_bytes(result.stderr)
(ROOT/'psql-exit.txt').write_text(str(result.returncode)+'\n')
sys.stdout.buffer.write(result.stdout)
sys.stderr.buffer.write(result.stderr)
sys.exit(result.returncode)
