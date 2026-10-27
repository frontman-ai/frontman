"""Exercise real subprocess exit, timeout, and owned database cleanup."""

import os
import signal
import subprocess
import sys
import tempfile
import time
import unittest
import uuid

from run_application_restart import run, run_owned


class RestartRunnerTest(unittest.TestCase):
    def test_preserves_failure(self):
        self.assertEqual(run(["sh", "-c", "exit 7"], os.environ.copy(), 5), 7)

    def test_bounds_process_group(self):
        self.assertEqual(run(["sh", "-c", "sleep 60 & wait"], os.environ.copy(), 0.1), 124)

    def test_failed_run_cleans_only_fresh_database(self):
        sentinel_env = os.environ.copy()
        sentinel_env.update(
            MIX_ENV="test", MIX_TEST_PARTITION="", MIX_TEST_DB_SUFFIX="_sentinel_" + uuid.uuid4().hex
        )
        previous = os.environ.get("MIX_TEST_DB_SUFFIX")
        with tempfile.TemporaryDirectory() as directory:
            suffix_file = os.path.join(directory, "suffix")
            try:
                self.assertEqual(run(["mix", "ecto.create", "--quiet"], sentinel_env, 60), 0)
                os.environ["MIX_TEST_DB_SUFFIX"] = sentinel_env["MIX_TEST_DB_SUFFIX"]
                self.assertEqual(
                    run_owned(
                        [
                            "sh",
                            "-c",
                            'test "$MIX_ENV" = test && test -z "$MIX_TEST_PARTITION" '
                            '&& case "$MIX_TEST_DB_SUFFIX" in _restart_*) ;; *) exit 9;; esac '
                            '&& printf "%s" "$MIX_TEST_DB_SUFFIX" > "$1" '
                            "&& mix ecto.create --quiet && exit 7",
                            "restart-cleanup-test",
                            suffix_file,
                        ]
                    ),
                    7,
                )
                with open(suffix_file) as file:
                    generated_suffix = file.read()
                self.assertNotEqual(generated_suffix, sentinel_env["MIX_TEST_DB_SUFFIX"])
                query_env = sentinel_env | {"GENERATED_DB_SUFFIX": generated_suffix}
                query = """
                {:ok, _} = Application.ensure_all_started(:postgrex)
                config = Application.fetch_env!(:frontman_server, FrontmanServer.Repo)
                sentinel = Keyword.fetch!(config, :database)
                generated = "frontman_server_test" <> System.fetch_env!("GENERATED_DB_SUFFIX")
                options = config |> Keyword.take([:hostname, :username, :password])
                {:ok, connection} = Postgrex.start_link(Keyword.put(options, :database, "postgres"))
                %{rows: rows} = Postgrex.query!(connection,
                  "SELECT datname FROM pg_database WHERE datname = ANY($1)",
                  [[sentinel, generated]], timeout: 5_000)
                [[^sentinel]] = rows
                """
                self.assertEqual(run(["mix", "run", "--no-start", "-e", query], query_env, 60), 0)
            finally:
                if previous is None:
                    os.environ.pop("MIX_TEST_DB_SUFFIX", None)
                else:
                    os.environ["MIX_TEST_DB_SUFFIX"] = previous
                self.assertEqual(run(["mix", "ecto.drop", "--quiet"], sentinel_env, 60), 0)

    def test_interrupt_waits_for_child(self):
        with tempfile.TemporaryDirectory() as directory:
            pid_file = os.path.join(directory, "pid")
            program = (
                "import signal; from run_application_restart import run; "
                "signal.signal(signal.SIGTERM, lambda *_: exit(143)); "
                f"run(['sh', '-c', 'echo $$ > {pid_file}; exec sleep 60'], {{}}, 30)"
            )
            process = subprocess.Popen([sys.executable, "-c", program], cwd=os.path.dirname(__file__))
            try:
                for _ in range(100):
                    if os.path.exists(pid_file):
                        break
                    time.sleep(0.02)
                with open(pid_file) as file:
                    child = int(file.read())
                process.send_signal(signal.SIGTERM)
                self.assertEqual(process.wait(timeout=5), 143)
                with self.assertRaises(ProcessLookupError):
                    os.kill(child, 0)
            finally:
                if process.poll() is None:
                    process.kill()
                    process.wait()


if __name__ == "__main__":
    unittest.main()
