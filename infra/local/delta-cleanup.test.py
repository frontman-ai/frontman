import hashlib
import os
import pathlib
import shutil
import subprocess
import tempfile
import time
import uuid


ROOT = pathlib.Path(__file__).resolve().parents[2]
IMAGE = "localhost/frontman-dev:latest"
LABEL = "frontman.cleanup-test"
TOKEN = uuid.uuid4().hex


def podman(*args):
    return subprocess.check_output(["podman", *args], text=True).strip()


def wait_for_pid(container):
    deadline = time.monotonic() + 10
    while time.monotonic() < deadline:
        result = subprocess.run(
            ["podman", "exec", container, "cat", "/tmp/frontman-supervisor.pid"],
            capture_output=True, text=True,
        )
        if result.returncode == 0:
            return result.stdout.strip()
        time.sleep(0.1)
    raise AssertionError("Process did not write its PID")


podman("image", "exists", IMAGE)
with tempfile.TemporaryDirectory(prefix="frontman-cleanup-") as directory:
    checkout = pathlib.Path(directory)
    for name in ("bin/delta-stack", "infra/local/delta-dev.sh", "infra/local/delta-lifecycle.py"):
        destination = checkout / name
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(ROOT / name, destination)
    pod = "delta-frontman-" + hashlib.sha256(str(checkout.resolve()).encode()).hexdigest()[:12]
    other = pod + "-unrelated"
    volumes = [pod + "-pgdata", pod + "-mysql", other + "-data"]
    pods = []
    processes = []

    def stack(action, confirm=""):
        return subprocess.run(
            ["bash", str(checkout / "bin/delta-stack"), action],
            env={**os.environ, "CONFIRM": confirm, "DELTA_LIFECYCLE_LOCKED": ""},
            capture_output=True, text=True, timeout=40,
        )

    def assert_stopped():
        assert podman("pod", "inspect", pod, "--format", "{{.State}}") == "Exited"
        assert podman("pod", "inspect", other, "--format", "{{.State}}") == "Running"

    try:
        for volume in volumes:
            podman("volume", "create", "--label", f"{LABEL}={TOKEN}", volume)
        for name, volume in ((pod, volumes[0]), (other, volumes[2])):
            podman("pod", "create", "--name", name, "--label", f"{LABEL}={TOKEN}")
            pods.append(name)
            podman(
                "run", "-d", "--init", "--user", "root", "--pull=never", "--pod", name,
                "--name", name + "-dev", "--stop-timeout", "1",
                "-v", f"{checkout}:/workspaces/frontman:ro",
                "-v", f"{volume}:/data", IMAGE, "sleep", "infinity",
            )
        podman("exec", pod + "-dev", "bash", "-c", "printf retained > /data/sentinel")

        for scenario in ("dead-supervisor", "unresponsive-supervisor"):
            command = 'echo "$$" > /tmp/frontman-supervisor.pid; exec sleep infinity'
            if scenario == "unresponsive-supervisor":
                command = "trap '' TERM; " + command
            process = subprocess.Popen(
                ["podman", "exec", pod + "-dev", "bash", "-c", command],
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            )
            processes.append(process)
            pid = wait_for_pid(pod + "-dev")
            if scenario == "dead-supervisor":
                podman("exec", pod + "-dev", "kill", "-KILL", pid)
                process.wait(timeout=10)
                result = subprocess.run(
                    ["podman", "exec", "-w", "/workspaces/frontman", pod + "-dev",
                     "bash", "infra/local/delta-dev.sh", "stop"],
                    capture_output=True, text=True, timeout=5,
                )
                assert result.returncode == 0, result.stderr
                podman("exec", pod + "-dev", "test", "!", "-e", "/tmp/frontman-supervisor.pid")
                podman("exec", pod + "-dev", "bash", "-c",
                       f"printf '%s' {pid} > /tmp/frontman-supervisor.pid")
            result = stack("stop")
            assert result.returncode == 0, result.stderr
            if scenario == "unresponsive-supervisor":
                assert "Graceful supervisor shutdown failed" in result.stderr
            assert_stopped()
            process.wait(timeout=5)
            podman("pod", "start", pod)
            assert podman("exec", pod + "-dev", "cat", "/data/sentinel") == "retained"
            podman("exec", pod + "-dev", "rm", "-f", "/tmp/frontman-supervisor.pid")
            print(scenario + ": stop completed, data retained, unrelated pod running")

        rejected = stack("remove", "wrong-pod")
        assert rejected.returncode != 0
        assert podman("pod", "inspect", pod, "--format", "{{.State}}") == "Running"
        podman("pod", "rm", "--force", pod)
        for attempt in range(2):
            result = stack("remove", pod)
            assert result.returncode == 0, result.stderr
            for volume in volumes[:2]:
                assert subprocess.run(["podman", "volume", "exists", volume]).returncode == 1
            assert podman("pod", "inspect", other, "--format", "{{.State}}") == "Running"
            podman("volume", "exists", volumes[2])
        print("Absent pod and partial volumes removed; repeated removal succeeded; confirmation enforced")
    finally:
        for name in pods:
            if subprocess.run(["podman", "pod", "exists", name]).returncode == 0:
                assert podman("pod", "inspect", name, "--format",
                              '{{index .Labels "' + LABEL + '"}}') == TOKEN
                podman("pod", "rm", "--force", name)
        for process in processes:
            process.wait(timeout=10)
        for volume in volumes:
            if subprocess.run(["podman", "volume", "exists", volume]).returncode == 0:
                assert podman("volume", "inspect", volume, "--format",
                              '{{index .Labels "' + LABEL + '"}}') == TOKEN
                podman("volume", "rm", volume)
