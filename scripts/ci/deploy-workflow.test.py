import fnmatch
import os
import re
import subprocess
import tempfile
from itertools import product
from pathlib import Path

workflow = Path('.github/workflows/deploy.yml').read_text()
jobs = dict(re.findall(r'^  ([\w-]+):\n(.*?)(?=^  [\w-]+:|\Z)', workflow, re.M | re.S))
config = {job: body.split('    steps:', 1)[0] for job, body in jobs.items()}
assert 'actions: read' in config['changes'] and 'actions: write' not in workflow
assert 'fetch-depth: 0' in jobs['changes']
assert "base: ${{ steps.baseline.outputs.base }}" in jobs['changes']
assert "ref: ${{ github.sha }}" in jobs['changes']
assert "if: steps.baseline.outputs.force != 'true'" in jobs['changes']
for job, app in [('build-client', 'client'), ('deploy-server', 'server')]:
    assert 'needs: changes' in config[job]
    assert f"if: needs.changes.outputs.{app} == 'true'" in config[job]
assert 'needs: [changes, build-client, deploy-server]' in config['deploy-client']
assert 'continue-on-error:' not in ''.join(config.values())

guard = config['deploy-client'].split('${{', 1)[1].split('}}', 1)[0].strip()
for client, server, wanted_server, wanted_client, changes, cancelled in product(
    ('success', 'failure', 'cancelled', 'skipped'),
    ('success', 'failure', 'cancelled', 'skipped'), ('true', 'false'), ('true', 'false'),
    ('success', 'failure', 'cancelled', 'skipped'), (True, False)
):
    expression = guard.replace('!cancelled()', str(not cancelled)).replace('&&', ' and ').replace('||', ' or ')
    values = {'changes.result': changes, 'changes.outputs.client': wanted_client,
              'changes.outputs.server': wanted_server, 'build-client.result': client, 'deploy-server.result': server}
    for key, value in values.items():
        expression = expression.replace('needs.' + key, repr(value))
    assert eval(' '.join(expression.split()), {'__builtins__': {}}) == (
        not cancelled and changes == 'success' and wanted_client == 'true' and client == 'success' and
        (server == 'success' or (wanted_server == 'false' and server == 'skipped'))
    )

filters = jobs['changes'].split('          filters: |\n', 1)[1]
patterns = {app: re.findall(r"- '([^']+)'", body) for app, body in
            re.findall(r'^            (\w+):\n(.*?)(?=^            \w+:|\Z)', filters, re.M | re.S)}
triggers = re.findall(r"- '([^']+)'", workflow.split('  workflow_dispatch:', 1)[0])
for paths, expected in [
    (['apps/frontman_server/lib/server.ex'], {'server'}),
    (['apps/swarm_ai/mix.lock'], {'server'}),
    (['libs/client/src/Client.res'], {'client'}),
    (['libs/bindings/package.json'], {'client'}),
    (['apps/frontman_server/config/runtime.exs', 'libs/client/Makefile'], {'server', 'client'}),
    (['README.md'], set()), (['infra/production/monitoring/prometheus.yml'], {'server'}),
    *[([p], {'client'}) for p in ('package.json', 'yarn.lock', '.yarnrc.yml', '.yarn/releases/yarn.cjs', 'rescript.json')],
    *[([p], {'server', 'client'}) for p in ('mise.toml', 'Makefile', '.github/workflows/deploy.yml', '.github/actions/discord-notify/action.yml')],
]:
    assert {app for app, pats in patterns.items() if any(fnmatch.fnmatch(p, pat) for p in paths for pat in pats)} == expected
    if expected:
        assert all(any(fnmatch.fnmatch(p, pat) for pat in triggers if not pat.startswith('!')) for p in paths)

shell = re.search(r'        run: \|\n(.*?)(?=^      -)', jobs['changes'], re.M | re.S)[1]
shell = '\n'.join(line[10:] for line in shell.splitlines())
with tempfile.TemporaryDirectory() as tmp:
    root = Path(tmp)
    def git(*args):
        return subprocess.check_output(['git', *args], cwd=root, text=True).strip()
    git('init', '-q')
    git('config', 'user.name', 'Test')
    git('config', 'user.email', 'test@example.com')
    git('commit', '--allow-empty', '-qm', 'deployed')
    deployed = git('rev-parse', 'HEAD')
    (root / 'server').write_text('undeployed server change')
    git('add', 'server')
    git('commit', '-qm', 'failed server deployment')
    failed = git('rev-parse', 'HEAD')
    (root / 'client').write_text('client change after cancellation')
    git('add', 'client')
    git('commit', '-qm', 'client change')
    head = git('rev-parse', 'HEAD')
    nonancestor = git('commit-tree', 'HEAD^{tree}', '-m', 'unrelated history')
    api = root / 'gh'
    api.write_text('#!/bin/bash\n[[ "$*" == *"branch=main&event=push&status=success&per_page=1"* ]] || exit 9\nprintf "%s" "$BASE"\nexit "$API_STATUS"\n')
    api.chmod(0o755)
    for event, ref, base, status, force in [
        ('push', 'refs/heads/main', deployed, '0', 'false'),
        ('push', 'refs/heads/main', '', '0', 'true'),
        ('push', 'refs/heads/main', head, '0', 'true'),
        ('push', 'refs/heads/main', nonancestor, '0', 'true'),
        ('push', 'refs/heads/main', 'f' * 40, '0', 'true'),
        ('push', 'refs/heads/main', '', '1', 'true'),
        ('workflow_dispatch', 'refs/heads/main', deployed, '0', 'true'),
        ('workflow_dispatch', 'refs/heads/feature', deployed, '0', 'true'),
        ('push', 'refs/heads/feature', deployed, '0', 'true'),
    ]:
        output = root / 'output'
        output.write_text('')
        result = subprocess.run(['bash', '-e', '-o', 'pipefail', '-c', shell], cwd=root, text=True, capture_output=True,
                                env={**os.environ, 'PATH': f'{root}:{os.environ["PATH"]}', 'EVENT': event, 'REF': ref,
                                     'BASE': base, 'API_STATUS': status, 'GH_REPO': 'test/repo', 'GITHUB_OUTPUT': str(output)})
        assert result.returncode == 0, result.stderr
        assert f'force={force}\n' in output.read_text()
        if force == 'false':
            assert f'base={deployed}\n' in output.read_text()
            assert set(git('diff', '--name-only', deployed, head).splitlines()) == {'server', 'client'}
            assert git('diff', '--name-only', failed, head) == 'client'
        if status == '1':
            assert '::warning::' in result.stdout
print('Deployment filters, prerequisite guards, and actual baseline shell checks passed.')
