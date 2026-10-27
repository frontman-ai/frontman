"""Run real application restart tests in an owned database and bounded process group."""

import os
import signal
import subprocess
import sys
import uuid


def run(command, env, timeout):
    process = subprocess.Popen(command, env=env, start_new_session=True)
    try:
        return process.wait(timeout=timeout)
    except subprocess.TimeoutExpired:
        os.killpg(process.pid, signal.SIGKILL)
        process.wait()
        print(f"Timed out after {timeout}s: {command}", file=sys.stderr)
        return 124
    except BaseException:
        os.killpg(process.pid, signal.SIGKILL)
        process.wait()
        raise


def run_owned(command, timeout=300):
    env = os.environ.copy()
    env["MIX_ENV"] = "test"
    env["MIX_TEST_PARTITION"] = ""
    env["MIX_TEST_DB_SUFFIX"] = "_restart_" + uuid.uuid4().hex
    print("Owned test database suffix: " + env["MIX_TEST_DB_SUFFIX"], flush=True)
    result = 1
    try:
        result = run(command, env, timeout)
    finally:
        cleanup = run(["mix", "ecto.drop", "--quiet"], env, 60)
    return result if result else cleanup


if __name__ == "__main__":
    def abort(signum, _frame):
        raise SystemExit(128 + signum)

    signal.signal(signal.SIGINT, abort)
    signal.signal(signal.SIGTERM, abort)
    sys.exit(run_owned(["make", "test", "TEST_ARGS=--only application_restart --seed 0"]))
