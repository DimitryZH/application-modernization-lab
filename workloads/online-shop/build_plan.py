"""Git-object build contract validator/planner. Python 3.10+, Git; no Docker required."""
import argparse
import fnmatch
import hashlib
import json
from pathlib import PurePosixPath
import re
import shlex
import subprocess
import sys

WORKLOAD = 'workloads/online-shop'
REPOSITORY = 'https://github.com/DimitryZH/application-modernization-lab'


def git(repo, *args):
    return subprocess.check_output(['git', '-C', str(repo), *args], stderr=subprocess.PIPE)


def path(value):
    if not isinstance(value, str) or not value or '\\' in value or ':' in value:
        raise ValueError('invalid relative path')
    p = PurePosixPath(value)
    if p.is_absolute() or '..' in p.parts or str(p) != value:
        raise ValueError('path escapes or is not canonical: ' + value)
    return value


class Source:
    def __init__(self, repo, revision):
        if not re.fullmatch('[0-9a-f]{40}', revision):
            raise ValueError('revision must be a full lowercase 40-character SHA')
        if git(repo, 'rev-parse', revision + '^{commit}').decode().strip() != revision:
            raise ValueError('revision is not a commit')
        self.repo, self.revision = repo, revision
        self.entries = {}
        for row in git(repo, 'ls-tree', '-rz', revision).split(b'\0'):
            if row:
                metadata, name = row.split(b'\t')
                mode, kind, oid = metadata.decode().split()
                self.entries[name.decode()] = (mode, kind, oid)
        self.cache = {}
        names = [n for n, entry in self.entries.items() if n.startswith(WORKLOAD + '/') and entry[0] in ('100644', '100755')]
        batch = subprocess.run(['git', '-C', str(repo), 'cat-file', '--batch'],
                               input=''.join(self.entries[n][2] + '\n' for n in names).encode(),
                               stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True).stdout
        offset = 0
        for name in names:
            end = batch.index(b'\n', offset)
            size = int(batch[offset:end].split()[2])
            self.cache[name] = batch[end + 1:end + 1 + size]
            offset = end + size + 2

    def read(self, name):
        path(name)
        if name not in self.entries or self.entries[name][0] not in ('100644', '100755'):
            raise ValueError('missing/non-regular input: ' + name)
        if name not in self.cache:
            self.cache[name] = git(self.repo, 'cat-file', 'blob', self.entries[name][2])
        data = self.cache[name]
        if data.startswith(b'version https://git-lfs.github.com/spec/v1'):
            raise ValueError('external Git LFS input: ' + name)
        return data

    def json(self, name):
        return json.loads(self.read(name))


def ignored(name, rules):
    # Deliberately support only the existing simple ignore rules. Fail closed on
    # new negation/complex patterns rather than approximate Docker semantics.
    for rule in rules:
        if rule.startswith('!') or rule.startswith('/') or '**' in rule and rule not in (
                '**/*.sh', '**/*.bat', '**/bin/', '**/obj/', '**/out/'):
            raise ValueError('unsupported dockerignore rule: ' + rule)
        if rule.startswith('**/'):
            tail = rule[3:].rstrip('/')
            if rule.endswith('/') and tail in PurePosixPath(name).parts[:-1]:
                return True
            if not rule.endswith('/') and fnmatch.fnmatchcase(PurePosixPath(name).name, tail):
                return True
        elif rule.endswith('/') or '/' not in rule:
            if fnmatch.fnmatchcase(name.split('/')[0], rule.rstrip('/')):
                return True
        else:
            raise ValueError('unsupported dockerignore rule: ' + rule)
    return False


def inventory(source, component):
    context = component['buildContext']
    dockerfile = component['dockerfile']
    text = source.read(WORKLOAD + '/' + dockerfile).decode()
    ignore_name = WORKLOAD + '/' + context + '/.dockerignore'
    if WORKLOAD + '/' + dockerfile + '.dockerignore' in source.entries:
        raise ValueError('Dockerfile-specific ignore needs a contract update')
    rules = [r.strip() for r in source.read(ignore_name).decode().splitlines()
             if r.strip() and not r.startswith('#')] if ignore_name in source.entries else []
    files = {}
    prefix = WORKLOAD + '/' + context + '/'
    for name in sorted(source.entries):
        if name.startswith(prefix):
            relative = name[len(prefix):]
            if not ignored(relative, rules):
                files[relative] = source.read(name)
    copies, consumed = [], set()
    for line in text.splitlines():
        if not re.match(r'^(COPY|ADD)\s', line):
            continue
        if line.startswith('ADD '):
            raise ValueError('ADD requires explicit planner support')
        value = line[5:]
        if value.startswith('--from='):
            continue
        if value.startswith('--') or '$' in value or value.endswith('\\'):
            raise ValueError('unsupported COPY syntax')
        tokens = json.loads(value) if value.startswith('[') else shlex.split(value)
        for item in tokens[:-1]:
            item = item.removeprefix('./')
            if item != '.':
                path(item)
            matches = [f for f in files if item == '.' or f == item or f.startswith(item + '/')
                       or fnmatch.fnmatchcase(f, item)]
            if not matches:
                raise ValueError('missing COPY input: ' + item)
            consumed.update(matches)
            copies.append(item)
    args = {}
    for name, default in re.findall(r'^ARG ([A-Z_][A-Z_0-9]*)(?:=([^\n]*))?$', text, re.M):
        args[name] = default or None
    declared = component['buildArguments']
    if args != {k: v['default'] for k, v in declared.items()}:
        raise ValueError('Dockerfile ARG drift: ' + component['id'])
    bases = re.findall(r'^FROM (\S+)', text, re.M)
    if bases != component['fromImages']:
        raise ValueError('base image drift: ' + component['id'])
    result = []
    for f in sorted(consumed):
        result.append({'path': context + '/' + f, 'sha256': hashlib.sha256(files[f]).hexdigest()})
    return {'copySources': copies, 'dockerignore': rules, 'inputs': result,
            'dockerfileSha256': hashlib.sha256(source.read(WORKLOAD + '/' + dockerfile)).hexdigest()}


def plan(repo, revision, selected, platform='linux/amd64', overrides=()):
    source = Source(repo, revision)
    contract = source.json(WORKLOAD + '/build.contract.json')
    if contract['contractVersion'] != 1 or contract['repository'] != REPOSITORY or contract['workloadPath'] != WORKLOAD:
        raise ValueError('unsupported contract identity/version')
    historical = {c['id']: c for c in source.json(WORKLOAD + '/images.lock.json')['components'] if c['sourcePath']}
    components = contract['components']
    by_id = {c['id']: c for c in components}
    if len(by_id) != len(components) or set(by_id) != set(historical) or len(by_id) != 11:
        raise ValueError('incomplete/duplicate component mapping')
    if not selected or len(selected) != len(set(selected)) or set(selected) - set(by_id):
        raise ValueError('empty, duplicate or unknown component selection')
    values = {}
    for item in overrides:
        key, value = item.split('=', 1)
        component_id, name = key.split('.', 1)
        if component_id not in selected or (component_id, name) in values:
            raise ValueError('argument component not selected or duplicate argument')
        values[component_id, name] = value
    output = []
    for c in sorted(components, key=lambda c: c['id']):
        for field in ('sourcePath', 'buildContext', 'dockerfile', 'role'):
            if c[field] != historical[c['id']][field]:
                raise ValueError('historical mapping drift: ' + field)
        for field in ('sourcePath', 'buildContext', 'dockerfile'):
            path(c[field])
        if not (c['buildContext'] == c['sourcePath'] or c['buildContext'].startswith(c['sourcePath'] + '/')) or not c['dockerfile'].startswith(c['buildContext'] + '/'):
            raise ValueError('path escapes source boundary')
        if c['target'] is not None or c['preparation'] != [] or c['platforms'] != ['linux/amd64']:
            raise ValueError('unsupported target/preparation/platform contract')
        for field in ('generatedInputs', 'dependencyFiles', 'assets', 'externalDownloads', 'limitations', 'regeneration'):
            if field not in c:
                raise ValueError('missing contract field: ' + field)
        for name in c['dependencyFiles'] + c['assets']:
            path(name)
            if not name.startswith(c['buildContext'] + '/'):
                raise ValueError('dependency escapes build context')
            source.read(WORKLOAD + '/' + name)
        for generated in c['generatedInputs']['paths']:
            name = c['buildContext'] + '/' + generated.rstrip('/')
            path(name)
            if generated.endswith('/'):
                matches = [n for n in source.entries if n.startswith(WORKLOAD + '/' + name + '/')]
                if not matches:
                    raise ValueError('missing generated inputs: ' + name)
                for match in matches:
                    source.read(match)
            else:
                source.read(WORKLOAD + '/' + name)
        regen = c['regeneration']
        for name in regen['sourceInputs'] + ([regen['script']] if regen['script'] else []):
            source.read(WORKLOAD + '/' + path(name))
        inputs = inventory(source, c)
        if c['id'] not in selected:
            continue
        if platform not in c['platforms']:
            raise ValueError('unsupported platform')
        arguments = {}
        for name, spec in c['buildArguments'].items():
            value = values.pop((c['id'], name), spec['intended'])
            if value == '$SOURCE_REVISION':
                value = revision
            if name == 'SOURCE_REVISION' and value != revision:
                raise ValueError('SOURCE_REVISION must equal selected commit')
            if name != 'SOURCE_REVISION' and value not in spec['allowedValues']:
                raise ValueError('unsupported build argument value')
            arguments[name] = value
        output.append({k: c[k] for k in ('id', 'sourcePath', 'buildContext', 'dockerfile', 'target', 'preparation')} |
                      {'buildArguments': arguments, **inputs})
    if values:
        raise ValueError('unknown build argument')
    return {'planVersion': 1, 'contractVersion': 1, 'repository': REPOSITORY,
            'sourceRevision': revision, 'toolingRevision': revision, 'workloadPath': WORKLOAD,
            'platform': platform, 'components': output}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repo', default='.')
    parser.add_argument('--revision', required=True)
    parser.add_argument('--components', nargs='+', required=True)
    parser.add_argument('--platform', default='linux/amd64')
    parser.add_argument('--build-arg', action='append', default=[])
    args = parser.parse_args()
    try:
        result = plan(args.repo, args.revision, args.components, args.platform, args.build_arg)
        print(json.dumps(result, indent=2, sort_keys=True))
    except (ValueError, KeyError, TypeError, subprocess.CalledProcessError) as error:
        print('build contract error: ' + str(error), file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
