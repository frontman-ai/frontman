import itertools
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
HELPER = ROOT / ".github/self_hosted_checks.py"


class ScopeTest(unittest.TestCase):
    def git(self, *args):
        return subprocess.check_output(
            ["git", *args], cwd=self.repo, stderr=subprocess.PIPE
        ).decode().strip()

    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.repo = Path(self.directory.name)
        self.git("init", "-q")
        self.git("config", "user.name", "CI scope test")
        self.git("config", "user.email", "ci-scope@example.invalid")
        self.git("commit", "--allow-empty", "-qm", "base")
        self.base = self.git("rev-parse", "HEAD")

    def run_helper(self, mode, **env):
        return subprocess.run(
            ["python3", str(HELPER), mode],
            cwd=self.repo,
            env={**os.environ, **env},
            capture_output=True,
            text=True,
        )

    def detect(self, paths, expected, event="pull_request", full="", base=None):
        self.git("reset", "--hard", self.base)
        for path in paths:
            target = self.repo / path
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text("changed\n")
        self.git("add", ".")
        self.git("commit", "--allow-empty", "-qm", "change")
        output = self.repo / "outputs"
        output.unlink(missing_ok=True)
        result = self.run_helper(
            "detect",
            EVENT_NAME=event,
            FULL_VERIFICATION=full,
            BASE_SHA=base or self.base,
            HEAD_SHA=self.git("rev-parse", "HEAD"),
            GITHUB_OUTPUT=str(output),
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            dict(line.split("=") for line in output.read_text().splitlines()), expected
        )
        output.unlink()

    def test_real_git_path_decisions(self):
        none = {"swarm": "false", "server": "false"}
        server = {"swarm": "false", "server": "true"}
        all_jobs = {"swarm": "true", "server": "true"}
        cases = [
            (["apps/marketing/blog/post.md", "apps/marketing/public/cover.png",
              ".changeset/marketing.md"], none),
            (["docs/protocol.md"], none),
            (["README.md"], none),
            ([".changeset/release.md"], none),
            ([], none),
        ]
        for path in ("lib/example.ex", "test/example_test.exs", "mix.lock", "mix.exs"):
            cases.append(([f"apps/frontman_server/{path}"], server))
            cases.append(([f"apps/swarm_ai/{path}"], all_jobs))
        for path in (
            "Makefile", "mise.toml", "package.json", "yarn.lock", ".yarnrc.yml",
            "rescript.json", ".github/workflows/ci.yml",
            ".github/self_hosted_checks.py", "scripts/ci/helper.sh",
            "libs/frontman-protocol/schemas/acp/schema.json",
            "unknown/file", "test/ci-scope/scope_test.py",
        ):
            cases.append(([path], all_jobs))
        for paths, expected in cases:
            with self.subTest(paths=paths):
                self.detect(paths, expected)

    def test_non_pr_and_reusable_call_are_full(self):
        for event, full in (("push", ""), ("workflow_call", ""),
                            ("pull_request", "true"), ("unknown", "")):
            with self.subTest(event=event, full=full):
                self.detect(["docs/only.md"], {"swarm": "true", "server": "true"},
                            event=event, full=full)

    def test_git_failure_does_not_emit_decisions(self):
        output = self.repo / "outputs"
        result = self.run_helper(
            "detect", EVENT_NAME="pull_request", FULL_VERIFICATION="",
            BASE_SHA="a" * 40, HEAD_SHA=self.base, GITHUB_OUTPUT=str(output),
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(output.exists())

    def test_deletion_out_of_server(self):
        self.detect(["apps/frontman_server/lib/example.ex"],
                    {"swarm": "false", "server": "true"})
        self.base = self.git("rev-parse", "HEAD")
        self.git("rm", "apps/frontman_server/lib/example.ex")
        self.git("commit", "-qm", "delete server")
        output = self.repo / "outputs"
        result = self.run_helper(
            "detect", EVENT_NAME="pull_request", FULL_VERIFICATION="",
            BASE_SHA=self.base, HEAD_SHA=self.git("rev-parse", "HEAD"),
            GITHUB_OUTPUT=str(output),
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("server=true", output.read_text())

    def test_rename_out_of_server_and_merge_base(self):
        self.detect(["apps/frontman_server/lib/example.ex"],
                    {"swarm": "false", "server": "true"})
        ancestor = self.git("rev-parse", "HEAD")
        self.git("checkout", "-qb", "pr")
        (self.repo / "docs").mkdir()
        self.git("mv", "apps/frontman_server/lib/example.ex", "docs/example.md")
        self.git("commit", "-qm", "move server file to docs")
        head = self.git("rev-parse", "HEAD")
        self.git("checkout", "-qb", "base", ancestor)
        (self.repo / "shared-root-config").write_text("base branch only\n")
        self.git("add", ".")
        self.git("commit", "-qm", "advance base")
        output = self.repo / "outputs"
        result = self.run_helper(
            "detect", EVENT_NAME="pull_request", FULL_VERIFICATION="false",
            BASE_SHA=self.git("rev-parse", "HEAD"), HEAD_SHA=head,
            GITHUB_OUTPUT=str(output),
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(output.read_text(), "swarm=false\nserver=true\n")

    def test_all_unselected_skipped_succeeds(self):
        needs = {
            "self-hosted-changes": {
                "result": "success", "outputs": {"swarm": "false", "server": "false"}
            },
            **{job: {"result": "skipped"} for job in
               ("test-swarm-ai", "test-frontman-server", "lint-frontman-server")},
        }
        result = self.run_helper("aggregate", NEEDS=json.dumps(needs))
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_aggregate_status_matrix(self):
        jobs = ("test-swarm-ai", "test-frontman-server", "lint-frontman-server")
        for swarm, server, result in itertools.product(
            ("true", "false"), ("true", "false"),
            ("success", "failure", "cancelled", "skipped"),
        ):
            for job in jobs:
                needs = {
                    "self-hosted-changes": {
                        "result": "success", "outputs": {"swarm": swarm, "server": server}
                    },
                    **{name: {"result": "success"} for name in jobs},
                }
                needs[job]["result"] = result
                selected = swarm if job == jobs[0] else server
                expected = result == "success" or (
                    result == "skipped" and selected == "false"
                )
                with self.subTest(swarm=swarm, server=server, job=job, result=result):
                    actual = self.run_helper("aggregate", NEEDS=json.dumps(needs))
                    self.assertEqual(actual.returncode == 0, expected, actual.stderr)

    def test_detection_failure_and_invalid_outputs_fail_aggregate(self):
        for result, outputs in itertools.product(
            ("failure", "cancelled", "skipped", "success"),
            ({}, {"swarm": "", "server": "false"}),
        ):
            needs = {
                "self-hosted-changes": {"result": result, "outputs": outputs},
                **{job: {"result": "skipped"} for job in
                   ("test-swarm-ai", "test-frontman-server", "lint-frontman-server")},
            }
            actual = self.run_helper("aggregate", NEEDS=json.dumps(needs))
            self.assertNotEqual(actual.returncode, 0)


if __name__ == "__main__":
    unittest.main()
