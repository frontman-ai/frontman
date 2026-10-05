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
for app in ('server', 'client', 'monitoring'):
    assert f"{app}: ${{{{ steps.baseline.outputs.force == 'true' || steps.paths.outputs.{app} == 'true' }}}}" in config['changes']
for job, app in [('build-client', 'client'), ('deploy-server', 'server'), ('deploy-monitoring', 'monitoring')]:
    assert 'needs: changes' in config[job]
    assert f"if: needs.changes.outputs.{app} == 'true'" in config[job]
assert 'needs: [changes, build-client, deploy-server]' in config['deploy-client']
assert 'continue-on-error:' not in ''.join(config.values())
assert 'deploy-monitoring' not in config['deploy-client']
monitoring = jobs['deploy-monitoring']
assert 'runs-on: self-hosted' in monitoring and 'environment: production' in monitoring
assert 'Sync monitoring configs' not in jobs['deploy-server']
assert "--exclude '/infra/production/monitoring'" in jobs['deploy-server']
assert 'MONITORING_STAGE: /opt/frontman/build/infra/production/monitoring' in monitoring
assert 'mkdir -p' in monitoring and 'infra/production/monitoring/ "deploy@${PROD_SERVER}:${MONITORING_STAGE}/"' in monitoring
assert '~/.ssh/deploy_key' not in monitoring and '~/.ssh/monitoring_deploy_key' not in jobs['deploy-server']
assert 'if: always()\n        run: rm -f ~/.ssh/monitoring_deploy_key' in monitoring

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
def matches(path, pattern):
    return fnmatch.fnmatchcase(path, pattern) and ('/**' in pattern or path.count('/') == pattern.count('/'))

triggers = re.findall(r"- '([^']+)'", workflow.split('  workflow_dispatch:', 1)[0])
for paths, expected in [
    (['apps/frontman_server/lib/server.ex'], {'server'}),
    (['apps/swarm_ai/mix.lock'], {'server'}),
    (['libs/client/src/Client.res'], {'client'}),
    (['libs/bindings/package.json'], {'client'}),
    (['apps/frontman_server/config/runtime.exs', 'libs/client/Makefile'], {'server', 'client'}),
    (['README.md'], set()),
    *[([f'infra/production/monitoring/{p}'], {'monitoring'}) for p in
      ('prometheus.yml', 'alert-rules.yml', 'blackbox.yml', 'alertmanager.yml', 'setup-monitoring.sh')],
    (['libs/client/src/Client.res', 'infra/production/monitoring/prometheus.yml'], {'client', 'monitoring'}),
    (['apps/frontman_server/mix.exs', 'infra/production/monitoring/prometheus.yml'], {'server', 'monitoring'}),
    *[([f'infra/production/{p}'], {'server'}) for p in
      ('deploy.sh', 'build-and-deploy.sh', 'rollback.sh', 'server-setup.sh', 'backup-pg.sh',
       'env.template', 'discord.env.template', 'Caddyfile.template', 'systemd/frontman-blue.service')],
    *[([f'infra/production/notifier/{p}'], set()) for p in ('setup.sh', 'build-and-deploy.sh', 'env.template')],
    (['infra/local/worktree-setup.sh'], set()),
    *[([p], {'client'}) for p in ('package.json', 'yarn.lock', '.yarnrc.yml', '.yarn/releases/yarn.cjs', 'rescript.json')],
    *[([p], {'server', 'client'}) for p in ('mise.toml', 'Makefile', '.github/actions/discord-notify/action.yml')],
    (['.github/workflows/deploy.yml'], {'server', 'client', 'monitoring'}),
]:
    assert {app for app, pats in patterns.items() if any(matches(p, pat) for p in paths for pat in pats)} == expected
    if expected:
        assert all(any(matches(p, pat) for pat in triggers if not pat.startswith('!')) for p in paths)

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
remote = re.search(r"bash -s -- .* <<'EOF'\n(.*?)\n          EOF", monitoring, re.S)[1]
remote = '\n'.join(line[10:] for line in remote.splitlines())
with tempfile.TemporaryDirectory() as tmp:
    root = Path(tmp)
    installed = root / 'prometheus'
    installed.touch()
    remote = remote.replace('/usr/local/bin/prometheus', str(installed))
    for name in ('prometheus.yml', 'alert-rules.yml', 'blackbox.yml', 'alertmanager.yml'):
        (root / name).write_text('current config')
    for command in ('sudo', 'curl'):
        mock = root / command
        mock.write_text('#!/bin/bash\necho "$*" >> "$LOG"\n'
                        '[[ "$1" != cp || -f "$2" ]] || exit 8\n'
                        f'[[ -z "$FAIL" || ( "$FAIL" != "{command}" && "$*" != *"$FAIL"* ) ]] || exit 9\n')
        mock.chmod(0o755)
    for failure in ('', 'sudo', '9090', '9093'):
        log = root / 'log'
        log.write_text('')
        result = subprocess.run(['bash', '-c', remote, '--', str(root)], text=True, capture_output=True,
                                env={**os.environ, 'PATH': f'{root}:{os.environ["PATH"]}',
                                     'LOG': str(log), 'FAIL': failure})
        assert (result.returncode == 0) == (failure == ''), result.stderr
        assert ('Monitoring configs synced and reloaded.' in result.stdout) == (failure == '')
        assert len(log.read_text().splitlines()) == {'': 8, 'sudo': 1, '9090': 7, '9093': 8}[failure]
    for directory in ('source', 'destination'):
        (root / directory / 'infra/production/monitoring').mkdir(parents=True)
    staged = root / 'destination/infra/production/monitoring/prometheus.yml'
    staged.write_text('current monitoring upload')
    (root / 'source/server').write_text('new server source')
    exclusions = re.findall(r"--exclude '([^']+)'", jobs['deploy-server'])
    subprocess.run(['rsync', '-a', '--delete', *[f'--exclude={p}' for p in exclusions],
                    f'{root}/source/', f'{root}/destination/'], check=True)
    assert staged.read_text() == 'current monitoring upload'
    assert (root / 'destination/server').read_text() == 'new server source'
print('Deployment filters, prerequisite guards, baseline and monitoring shell checks passed.')
