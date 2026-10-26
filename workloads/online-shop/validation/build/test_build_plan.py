"""Behavior tests against a real workload snapshot in a disposable Git repository."""
import importlib.util
import json
import hashlib
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[4]
spec = importlib.util.spec_from_file_location('build_plan', ROOT / 'workloads/online-shop/build_plan.py')
bp = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bp)


class ContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        output = Path(__file__).parent / 'output'
        output.mkdir(exist_ok=True)
        cls.temp = tempfile.TemporaryDirectory(dir=output, ignore_cleanup_errors=True)
        cls.repo = Path(cls.temp.name)
        paths = subprocess.check_output(['git', '-C', str(ROOT), 'ls-files', 'workloads/online-shop'], text=True).splitlines()
        paths += ['workloads/online-shop/build.contract.json', 'workloads/online-shop/build_plan.py']
        for name in sorted(set(paths)):
            dest = cls.repo / name
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / name, dest)
        cls.git('init', '-q')
        cls.git('config', 'user.name', 'Contract Test')
        cls.git('config', 'user.email', 'contract@example.invalid')
        cls.git('config', 'core.autocrlf', 'false')
        cls.revision = cls.commit()
        cls.contract = cls.repo / bp.WORKLOAD / 'build.contract.json'
        cls.original = cls.contract.read_bytes()
        cls.ids = [c['id'] for c in json.loads(cls.original)['components']]

    @classmethod
    def git(cls, *args):
        return subprocess.check_output(['git', '-C', str(cls.repo), *args], stderr=subprocess.PIPE).decode().strip()

    @classmethod
    def commit(cls):
        cls.git('add', '.')
        cls.git('commit', '-qm', 'test: snapshot')
        return cls.git('rev-parse', 'HEAD')

    @classmethod
    def tearDownClass(cls):
        cls.temp.cleanup()

    def plan(self, **kw):
        return bp.plan(self.repo, kw.pop('revision', self.revision), kw.pop('selected', ['frontend']), **kw)

    def changed(self, edit):
        data = json.loads(self.original)
        edit(data)
        self.contract.write_text(json.dumps(data), encoding='utf-8')
        revision = self.commit()
        self.contract.write_bytes(self.original)
        return revision

    def test_complete_real_contract(self):
        result = self.plan(selected=self.ids)
        self.assertEqual(11, len(result['components']))
        self.assertTrue(all(c['inputs'] for c in result['components']))
        self.assertTrue(all(c['buildArguments']['SOURCE_REVISION'] == self.revision for c in result['components']))

    def test_one_and_determinism(self):
        self.assertEqual(1, len(self.plan()['components']))
        a = self.plan(selected=self.ids)
        b = self.plan(selected=list(reversed(self.ids)))
        self.assertEqual(json.dumps(a, sort_keys=True), json.dumps(b, sort_keys=True))

    def test_invalid_selections(self):
        for selection in ([], ['redis-cart'], ['frontend', 'frontend'], ['unknown']):
            with self.subTest(selection=selection), self.assertRaises(ValueError):
                self.plan(selected=selection)

    def test_revision_validation(self):
        for revision in ('main', 'HEAD', 'a'*39, 'z'*40, '0'*40):
            with self.subTest(revision=revision), self.assertRaises((ValueError, subprocess.CalledProcessError)):
                self.plan(revision=revision)

    def test_platform(self):
        with self.assertRaises(ValueError): self.plan(platform='linux/arm64')

    def test_arguments(self):
        good = self.plan(overrides=['frontend.SKAFFOLD_GO_GCFLAGS=all=-N -l'])
        self.assertEqual('all=-N -l', good['components'][0]['buildArguments']['SKAFFOLD_GO_GCFLAGS'])
        for overrides in (['frontend.UNKNOWN=x'], ['frontend.SOURCE_REVISION=development'],
                          ['frontend.SKAFFOLD_GO_GCFLAGS=arbitrary'], ['cartservice.SOURCE_REVISION=x'],
                          ['frontend.SKAFFOLD_GO_GCFLAGS=', 'frontend.SKAFFOLD_GO_GCFLAGS='], ['broken']):
            with self.subTest(overrides=overrides), self.assertRaises(ValueError): self.plan(overrides=overrides)

    def test_working_tree_and_head_isolation(self):
        before = self.plan()
        revision = self.changed(lambda c: c.update(contractVersion=999))
        self.assertNotEqual(revision, self.revision)
        (self.repo / bp.WORKLOAD / 'src/frontend/local-artifact.txt').write_text('untracked')
        self.assertEqual(before, self.plan())
        with self.assertRaises(ValueError): self.plan(revision=revision)

    def test_mapping_drift(self):
        revision = self.changed(lambda c: c['components'][0].update(buildContext='src/frontend'))
        with self.assertRaises(ValueError): self.plan(revision=revision)

    def test_path_escape(self):
        revision = self.changed(lambda c: c['components'][0]['dependencyFiles'].append('../outside'))
        with self.assertRaises(ValueError): self.plan(revision=revision)

    def test_missing_input(self):
        revision = self.changed(lambda c: c['components'][0]['dependencyFiles'].append('src/adservice/missing'))
        with self.assertRaises(ValueError): self.plan(revision=revision)

    def test_dockerfile_drift(self):
        file = self.repo / bp.WORKLOAD / 'src/frontend/Dockerfile'
        original = file.read_bytes()
        try:
            file.write_bytes(original + b'\nCOPY missing-file /missing\n')
            revision = self.commit()
            with self.assertRaises(ValueError): self.plan(revision=revision)
        finally: file.write_bytes(original)

    def test_ignore_and_boundary_semantics(self):
        self.assertTrue(bp.ignored('nested/bin/output', ['**/bin/']))
        self.assertFalse(bp.ignored('src/Program.cs', ['**/bin/', '**/*.sh']))
        self.assertTrue(bp.ignored('client.js', ['client.js']))
        for value in ('../secret', '/absolute', 'C:/outside', 'src/../secret', 'src\\file'):
            with self.subTest(value=value), self.assertRaises(ValueError): bp.path(value)
        with self.assertRaises(ValueError): bp.ignored('file', ['!file'])

    def snapshot_inventory(self, transform, extra=None):
        """Inventory a committed variant with a context not covered by COPY dot."""
        component = next(c for c in json.loads(self.original)['components'] if c['id'] == 'loadgenerator')
        name = bp.WORKLOAD + '/' + component['dockerfile']
        original = bp.git(self.repo, 'show', self.revision + ':' + name)
        file = self.repo / name
        extra_file = self.repo / bp.WORKLOAD / component['buildContext'] / 'extra.txt'
        try:
            file.write_text(transform(original.decode()), encoding='utf-8', newline='\n')
            if extra is not None:
                extra_file.write_bytes(extra)
            revision = self.commit()
            return bp.inventory(bp.Source(self.repo, revision), component)
        finally:
            file.write_bytes(original)
            extra_file.unlink(missing_ok=True)

    def test_copy_case_and_indentation(self):
        for instruction in ('copy', 'CoPy', '  COPY', '\t cOpY'):
            with self.subTest(instruction=instruction):
                result = self.snapshot_inventory(lambda text: text + '\n' + instruction + ' extra.txt /extra.txt\n', b'extra input\n')
                expected = {'path': 'src/loadgenerator/extra.txt', 'sha256': hashlib.sha256(b'extra input\n').hexdigest()}
                self.assertIn(expected, result['inputs'])
                self.assertIn('extra.txt', result['copySources'])

    def test_missing_copy_case_and_indentation(self):
        for instruction in ('copy', 'CoPy', '  COPY', '\t cOpY'):
            with self.subTest(instruction=instruction), self.assertRaisesRegex(ValueError, 'missing COPY input'):
                self.snapshot_inventory(lambda text: text + '\n' + instruction + ' missing.txt /missing.txt\n')

    def test_add_case_and_indentation_rejected(self):
        for instruction in ('add', 'AdD', '  ADD', '\t aDd'):
            with self.subTest(instruction=instruction), self.assertRaisesRegex(ValueError, 'ADD requires'):
                self.snapshot_inventory(lambda text: text + '\n' + instruction + ' extra.txt /extra.txt\n', b'extra')

    def test_from_and_arg_case_and_indentation(self):
        result = self.snapshot_inventory(lambda text: re.sub(r'^(FROM|ARG) ', lambda m: '  ' + m[1].lower() + '\t', text, flags=re.M).replace(' AS ', ' aS '))
        self.assertTrue(result['inputs'])
        with self.assertRaisesRegex(ValueError, 'ARG drift'):
            self.snapshot_inventory(lambda text: text + '\n  aRg UNDECLARED=value\n')
        with self.assertRaisesRegex(ValueError, 'base image drift'):
            self.snapshot_inventory(lambda text: text + '\n  fRoM undeclared:image\n')

    def test_internal_named_and_numeric_copies(self):
        baseline = self.snapshot_inventory(lambda text: text)
        for reference in ('base', 'builder', '0', '1'):
            with self.subTest(reference=reference):
                result = self.snapshot_inventory(lambda text: text + '\n  cOpY --from=' + reference + ' /generated /artifact\n')
                self.assertEqual(baseline['inputs'], result['inputs'])
                self.assertEqual(baseline['copySources'], result['copySources'])
        result = self.snapshot_inventory(lambda text: text.replace('--from=builder /install /usr/local', '--from=1 ["/install", "/usr/local"]'))
        self.assertEqual(baseline['inputs'], result['inputs'])

    def test_unknown_external_and_invalid_stage_references(self):
        for reference in ('buidler', 'named-context', 'alpine:3.20', 'docker.io/library/alpine:3.20',
                          'alpine@sha256:' + 'a'*64, '2', '3', '-1', '$STAGE'):
            with self.subTest(reference=reference), self.assertRaisesRegex(ValueError, 'earlier internal stage'):
                self.snapshot_inventory(lambda text: text + '\nCOPY --from=' + reference + ' /file /file\n')
        with self.assertRaisesRegex(ValueError, 'earlier internal stage'):
            self.snapshot_inventory(lambda text: text.replace('FROM base AS builder', 'FROM base AS builder\nCOPY --from=builder /file /file'))
        with self.assertRaisesRegex(ValueError, 'earlier internal stage'):
            self.snapshot_inventory(lambda text: text.replace('FROM base AS builder', 'FROM base AS builder\nCOPY --from=2 /file /file'))

    def test_unsupported_copy_syntax_cannot_bypass_stage_validation(self):
        for value in ('--from=builder --chown=1000 /a /b', '--chown=1000 --from=builder /a /b',
                      '--from=builder --from=base /a /b', '--from=builder',
                      '--from=builder /a', '--from=builder ["/a", 123]',
                      '--from=builder /$INPUT /b', '--from=builder <<EOF /b',
                      '--from=builder /a /b\\\n /c', 'extra.txt /b\\\n /c'):
            with self.subTest(value=value), self.assertRaises(ValueError):
                self.snapshot_inventory(lambda text: text + '\n  copy ' + value + '\n', b'extra')

    def test_unsupported_from_arg_and_onbuild_syntax(self):
        for instruction in ('  from --platform=linux/amd64 alpine', '  arg BAD="two words"',
                            '  onbuild copy extra.txt /extra.txt'):
            with self.subTest(instruction=instruction), self.assertRaises(ValueError):
                self.snapshot_inventory(lambda text: text + '\n' + instruction + '\n', b'extra')

    def test_shell_continuation_is_not_a_docker_instruction(self):
        result = self.snapshot_inventory(lambda text: text + '\nRUN echo \\\n  copy missing.txt /not-a-copy\n')
        self.assertNotIn('missing.txt', result['copySources'])


if __name__ == '__main__': unittest.main()
