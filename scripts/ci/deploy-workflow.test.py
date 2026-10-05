import re
from itertools import product
from pathlib import Path

workflow = Path('.github/workflows/deploy.yml').read_text()
jobs = dict(re.findall(r'^  ([\w-]+):\n(.*?)(?=^  [\w-]+:|\Z)', workflow, re.M | re.S))
needs = {}
for job in ('build-client', 'deploy-server', 'deploy-client'):
    config = jobs[job].split('    steps:', 1)[0]
    assert not re.search(r'^    (if|continue-on-error):', config, re.M), job
    needs[job] = re.findall(r'[\w-]+', re.search(r'^    needs: (.*)$', config, re.M)[1]) if '    needs:' in config else []
assert needs == {'build-client': [], 'deploy-server': [], 'deploy-client': ['build-client', 'deploy-server']}
for client, server in product(('success', 'failure', 'cancelled', 'skipped'), repeat=2):
    results = {'build-client': client, 'deploy-server': server}
    assert all(results[n] == 'success' for n in needs['deploy-server'])
    assert all(results[n] == 'success' for n in needs['deploy-client']) == (client == server == 'success')
