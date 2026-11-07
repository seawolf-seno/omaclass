import importlib.machinery
import importlib.util
import json
import pathlib
import unittest

path = pathlib.Path(__file__).resolve().parent.parent / "bin" / "omaclass-veyon"
loader = importlib.machinery.SourceFileLoader("omaclass_veyon", str(path))
spec = importlib.util.spec_from_loader("omaclass_veyon", loader)
helper = importlib.util.module_from_spec(spec)
loader.exec_module(helper)

LIST = '''Location "Home"
\tComputer "lab-01" (host address: "10.0.0.21" MAC address: "")
Location "Room 12"
\tComputer "lab-02" (host address: "lab-02.local" MAC address: "")
\tComputer "bad" (host address: "-oProxyCommand=x" MAC address: "")
\tComputer "bad2" (host address: "a b; rm -rf" MAC address: "")
'''


class HelperTests(unittest.TestCase):
    def test_parse_classes(self):
        classes = helper.parse_classes(LIST)
        self.assertEqual([c["name"] for c in classes], ["Home", "Room 12"])
        self.assertEqual(classes[0]["computers"], [{"name": "lab-01", "host": "10.0.0.21"}])
        self.assertEqual([c["host"] for c in classes[1]["computers"]], ["lab-02.local"])

    def test_host_validation(self):
        self.assertTrue(helper.valid_host("10.0.0.21"))
        self.assertTrue(helper.valid_host("lab-02.local"))
        self.assertFalse(helper.valid_host("-oProxyCommand=x"))
        self.assertFalse(helper.valid_host("a b"))
        self.assertFalse(helper.valid_host("x;y"))

    def test_run_refuses_unknown_features(self):
        self.assertEqual(helper.cmd_run(["start", "PowerDown", "{}", "1.2.3.4"])["ok"], False)
        self.assertEqual(helper.cmd_run(["exec", "ScreenLock", "{}", "1.2.3.4"])["ok"], False)

    def test_feature_args(self):
        self.assertEqual(json.loads(helper.parse_feature_args('{"text":"hi"}')), {"text": "hi"})
        self.assertEqual(helper.parse_feature_args("{}"), "{}")
        for bad in ['{"applications":"sh"}', '{"text":1}', '[1]', '{"text":"' + "x" * 600 + '"}']:
            with self.assertRaises(ValueError):
                helper.parse_feature_args(bad)

    def test_run_with_no_valid_hosts_does_nothing(self):
        self.assertEqual(helper.cmd_run(["start", "ScreenLock", "{}", "-bad"]), {"ok": True, "done": [], "failed": []})



class MergeTests(unittest.TestCase):
    def test_merge_attaches_room_computers(self):
        rooms = [{"name": "Room 12", "computers": [{"name": "lab-01", "host": "10.0.0.21"}]}]
        mastery = [{"id": "ap-csp", "name": "AP CSP", "room": "Room 12", "now": True, "students": ["Ava"]},
                   {"id": "fot", "name": "Foundations", "room": "", "sample": True, "students": ["Ben", 3]},
                   "junk"]
        merged = helper.merge_classes(mastery, rooms)
        self.assertEqual(len(merged), 2)
        self.assertEqual(merged[0]["computers"], [{"name": "lab-01", "host": "10.0.0.21"}])
        self.assertTrue(merged[0]["now"])
        self.assertEqual(merged[1]["computers"], [])
        self.assertEqual(merged[1]["students"], ["Ben"])


if __name__ == "__main__":
    unittest.main()
