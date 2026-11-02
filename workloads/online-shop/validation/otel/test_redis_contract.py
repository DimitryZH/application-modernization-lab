"""Negative drift checks against the real effective Compose model; no engine needed."""
import copy
import json
import subprocess
import unittest
from redis_contract import HERE, WORKLOAD, check, check_source


class SourceTests(unittest.TestCase):
    def setUp(self):
        self.contract = json.loads((WORKLOAD / "redis.runtime.json").read_text())
        mapping = json.loads((WORKLOAD / "images.lock.json").read_text())
        self.image = next(c["image"] for c in mapping["components"] if c["id"] == "redis-cart")
        self.source = json.loads((WORKLOAD / self.contract["sourceContract"]).read_text())

    def test_matching_official_canonical_and_runtime_references(self):
        check_source(self.contract, self.image, self.source)
        text = (WORKLOAD / "kubernetes/online-shop.yaml").read_text()
        self.assertIn(self.image["repository"] + "@" + self.image["digest"], text)
        self.assertEqual(self.source["publicationStatus"], "pending")

    def test_reject_reference_and_version_drift(self):
        for change in (lambda s:s["upstream"].update(repository="docker.io/other/redis"),
                       lambda s:s["canonical"].update(manifestDigest="sha256:" + "0"*64),
                       lambda s:s["upstream"].update(configDigest="sha256:" + "0"*64),
                       lambda s:s.update(platform="linux/arm64"), lambda s:s.update(redisVersion="7.4.8"),
                       lambda s:s.update(version=True)):
            source = copy.deepcopy(self.source);change(source)
            with self.assertRaises(AssertionError):check_source(self.contract, self.image, source)


class DriftTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.model = json.loads(subprocess.check_output(["docker", "compose", "-f", str(HERE / "compose.yaml"), "config", "--format", "json"], text=True))

    def test_current_contract(self):
        check(self.model)

    def test_reject_runtime_drift(self):
        for field, value in [("image", "redis:7-alpine"), ("platform", "linux/arm64"), ("command", ["redis-server"]), ("user", "0:0"), ("read_only", False), ("ports", [{"published": "6379"}]), ("volumes", []), ("cap_drop", []), ("security_opt", []), ("deploy", {"replicas": 2})]:
            with self.subTest(field=field), self.assertRaises((AssertionError, IndexError)):
                model = copy.deepcopy(self.model)
                model["services"]["redis-cart"][field] = value
                check(model)

    def test_reject_foreign_storage(self):
        model = copy.deepcopy(self.model)
        model["volumes"]["redis-data"] = {"external": True, "name": "existing-application-data"}
        with self.assertRaises(AssertionError):
            check(model)

    def test_reject_endpoint_drift(self):
        model = copy.deepcopy(self.model)
        model["services"]["cartservice"]["environment"]["REDIS_ADDR"] = "redis:6379"
        with self.assertRaises(AssertionError):
            check(model)


if __name__ == "__main__":
    unittest.main()
