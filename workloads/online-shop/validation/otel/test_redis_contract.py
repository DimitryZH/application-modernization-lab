"""Negative drift checks against the real effective Compose model; no engine needed."""
import copy
import json
import subprocess
import unittest
from redis_contract import HERE, check


class DriftTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.model = json.loads(subprocess.check_output(["docker", "compose", "-f", str(HERE / "compose.yaml"), "config", "--format", "json"], text=True))

    def test_current_contract(self):
        check(self.model)

    def test_reject_runtime_drift(self):
        for field, value in [("image", "redis:7-alpine"), ("platform", "linux/arm64"), ("command", ["redis-server"]), ("user", "0:0"), ("read_only", False), ("ports", [{"published": "6379"}]), ("volumes", []), ("cap_drop", [])]:
            with self.subTest(field=field), self.assertRaises((AssertionError, IndexError)):
                model = copy.deepcopy(self.model)
                model["services"]["redis-cart"][field] = value
                check(model)

    def test_reject_endpoint_drift(self):
        model = copy.deepcopy(self.model)
        model["services"]["cartservice"]["environment"]["REDIS_ADDR"] = "redis:6379"
        with self.assertRaises(AssertionError):
            check(model)


if __name__ == "__main__":
    unittest.main()
