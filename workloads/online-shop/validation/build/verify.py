"""Local acceptance only: execute a generated plan, never publish. Not a CI executor.

Run from an isolated clean LF checkout: python workloads/online-shop/validation/build/verify.py
Raw build logs and the portable result are written to ignored output/.
"""
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import uuid

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
spec = importlib.util.spec_from_file_location('build_plan', ROOT / 'workloads/online-shop/build_plan.py')
bp = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bp)


def fingerprints(source):
    names = sorted(n for n in source.entries if n.startswith((bp.WORKLOAD + '/src/', bp.WORKLOAD + '/protos/')))
    hashes = {k: hashlib.sha256() for k in ('gitBlob', 'lfCheckout', 'crlfCheckout')}
    for n in names:
        data = source.read(n)
        # Match Git text conversion for this workload: NUL-containing assets are binary.
        lf = data if b'\0' in data else data.replace(b'\r\n', b'\n')
        crlf = lf if b'\0' in data else lf.replace(b'\n', b'\r\n')
        for key, value in (('gitBlob', data), ('lfCheckout', lf), ('crlfCheckout', crlf)):
            hashes[key].update(n.encode() + value)
    return {'method': 'run.py: sorted repository-relative UTF-8 path + raw bytes; no separator',
            'fileCount': len(names), **{k: h.hexdigest() for k, h in hashes.items()}}


def main():
    revision = bp.git(ROOT, 'rev-parse', 'HEAD').decode().strip()
    if bp.git(ROOT, 'status', '--porcelain').strip():
        raise ValueError('acceptance requires a clean checkout')
    source = bp.Source(ROOT, revision)
    # Check bytes rather than trusting Git status, which normalizes CRLF.
    for name in source.entries:
        if name.startswith(bp.WORKLOAD + '/') and (ROOT / name).read_bytes() != source.read(name):
            raise ValueError('checkout differs from Git blob (use core.autocrlf=false): ' + name)
    ids = [c['id'] for c in source.json(bp.WORKLOAD + '/build.contract.json')['components']]
    plan = bp.plan(ROOT, revision, ids)
    for c in plan['components']:
        context = ROOT / bp.WORKLOAD / c['buildContext']
        for file in context.rglob('*'):
            if file.is_file() and file.relative_to(ROOT).as_posix() not in source.entries:
                raise ValueError('undeclared local context artifact')
    token = uuid.uuid4().hex[:8]
    output = HERE / 'output' / token
    output.mkdir(parents=True)
    (output / 'plan.json').write_text(json.dumps(plan, indent=2, sort_keys=True) + '\n')
    report = {'sourceRevision': revision, 'toolingRevision': revision, 'contractVersion': 1,
              'platform': plan['platform'], 'checkout': 'core.autocrlf=false; every tracked workload byte verified against Git blobs',
              'cache': 'BuildKit layer and Dockerfile dependency/compiler caches allowed; no --no-cache or --pull',
              'fingerprints': fingerprints(source), 'builds': []}
    old = bp.Source(ROOT, '469621fd011626f6ce1e7269034aee525d4fb183')
    report['historicalFingerprints'] = fingerprints(old)
    names = sorted(n for n in source.entries if n.startswith((bp.WORKLOAD + '/src/', bp.WORKLOAD + '/protos/')))
    report['historicalBlobComparison'] = {'samePaths': set(names) == {n for n in old.entries if n.startswith((bp.WORKLOAD + '/src/', bp.WORKLOAD + '/protos/'))},
                                         'changedPaths': [n for n in names if n not in old.entries or source.read(n) != old.read(n)]}
    for c in plan['components']:
        tag = 'aml-25-' + token + '-' + c['id'] + ':local'
        command = ['docker', 'build', '--platform', plan['platform'], '-t', tag,
                   '-f', bp.WORKLOAD + '/' + c['dockerfile']]
        for k, v in sorted(c['buildArguments'].items()): command += ['--build-arg', k + '=' + v]
        command += [bp.WORKLOAD + '/' + c['buildContext']]
        print('Building ' + c['id'], flush=True)
        with (output / (c['id'] + '.log')).open('w', encoding='utf-8') as log:
            result = subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT)
        record = {'id': c['id'], 'tag': tag, 'exitCode': result.returncode, 'command': command}
        if result.returncode == 0:
            image = json.loads(subprocess.check_output(['docker', 'image', 'inspect', tag]))[0]
            record.update(imageId=image['Id'], platform=image['Os'] + '/' + image['Architecture'],
                          revisionLabel=image['Config']['Labels'].get('org.opencontainers.image.revision'))
            if record['platform'] != plan['platform'] or record['revisionLabel'] != revision:
                record['verificationError'] = 'image platform/revision mismatch'
        report['builds'].append(record)
        (output / 'result.json').write_text(json.dumps(report, indent=2) + '\n')
        print(c['id'] + ': ' + ('PASS' if result.returncode == 0 and 'verificationError' not in record else 'FAIL'), flush=True)
    print('Result: validation/build/output/' + token + '/result.json', flush=True)
    return int(any(c['exitCode'] or 'verificationError' in c for c in report['builds']))


if __name__ == '__main__': sys.exit(main())
