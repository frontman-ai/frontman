"""Exercise real subprocess exit, timeout, and owned database cleanup."""

import os
import signal
import subprocess
import sys
import tempfile
import time
import unittest

from run_application_restart import run, run_owned


class RestartRunnerTest(unittest.TestCase):
    def test_preserves_failure(self):
        self.assertEqual(run(["sh", "-c", "exit 7"], os.environ.copy(), 5), 7)

    def test_bounds_process_group(self):
        self.assertEqual(run(["sh", "-c", "sleep 60 & wait"], os.environ.copy(), 0.1), 124)

    def test_failed_run_cleans_only_fresh_database(self):
        self.assertEqual(
            run_owned(
                [
                    "sh",
                    "-c",
                    'test "$MIX_ENV" = test && test -z "$MIX_TEST_PARTITION" '
                    '&& case "$MIX_TEST_DB_SUFFIX" in _restart_*) ;; *) exit 9;; esac '
                    "&& mix ecto.create --quiet && exit 7",
                ]
            ),
            7,
        )

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
