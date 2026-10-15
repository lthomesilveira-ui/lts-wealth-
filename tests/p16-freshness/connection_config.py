"""Explicit loopback-only libpq options, testable without a PostgreSQL client."""
import os

def local_connection_options(environ=None):
 env=os.environ if environ is None else environ
 host=env.get('PGHOST','127.0.0.1')
 if host not in {'127.0.0.1','localhost','::1'}:
  raise RuntimeError('Only loopback PostgreSQL is permitted')
 if any(env.get(key) for key in ('PGSERVICE','PGSERVICEFILE')):
  raise RuntimeError('libpq service configuration is not permitted in disposable QA')
 # Explicit hostaddr overrides ambient PGHOSTADDR and avoids DNS resolution.
 address='::1' if host=='::1' else '127.0.0.1'
 port=int(env.get('PGPORT','5432'))
 if not 1<=port<=65535:raise RuntimeError('Invalid PostgreSQL port')
 return dict(host=host,hostaddr=address,port=port,
             user=env.get('PGUSER','postgres'),password=env.get('PGPASSWORD','qa-only'),
             options='-c timezone=UTC -c search_path=public',connect_timeout=5,
             sslmode='disable',gssencmode='disable')
