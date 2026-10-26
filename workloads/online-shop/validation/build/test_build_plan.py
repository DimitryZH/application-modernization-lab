"""Behavior tests against a real workload snapshot in a disposable Git repository."""
import importlib.util
import json
from pathlib import Path
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


if __name__ == '__main__': unittest.main()
