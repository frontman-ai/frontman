import os
import pathlib
import signal
import subprocess
import sys
import tempfile
import time
import uuid


SCRIPT = str(pathlib.Path(__file__).with_name("delta-lifecycle.py").resolve())
PREFIX = "delta-lifecycle-test-" + uuid.uuid4().hex[:12]
LABEL = "frontman.lifecycle-test=" + PREFIX
IMAGE = "docker.io/library/alpine:latest"
pods = []
volumes = []
owners = []


def podman(*args):
    return subprocess.check_output(["podman", *args], text=True).strip()


def until(predicate):
    deadline = time.monotonic() + 35
    while time.monotonic() < deadline:
        if predicate():
            return
        time.sleep(0.2)
    raise AssertionError("Timed out waiting for lifecycle outcome")


def running(pod):
    return podman("inspect", pod + "-work", "--format", "{{.State.Running}}") == "true"


def create(suffix):
    pod = PREFIX + suffix
    podman("pod", "create", "--name", pod, "--label", LABEL)
    pods.append(pod)
    volume = pod + "-data"
    podman("volume", "create", "--label", LABEL, volume)
    volumes.append(volume)
    podman("run", "-d", "--pull=never", "--pod", pod, "--name", pod + "-work",
           "--label", LABEL, "-v", volume + ":/data", IMAGE,
           "sh", "-c", "while :; do sleep 1; done")
    podman("exec", pod + "-work", "sh", "-c", "echo preserved >/data/sentinel")
    return pod


def owner(pod, output, script=SCRIPT):
    process = subprocess.Popen(
        [sys.executable, script, "own", pod, "podman", "pod", "start", pod],
        start_new_session=True, stdout=output, stderr=output,
    )
    owners.append(process)
    time.sleep(1)
    if process.poll() is not None:
        output.seek(0)
        raise AssertionError(output.read())
    until(lambda: "already has an active" in subprocess.run(
        [sys.executable, SCRIPT, "guard", pod, "true"],
        capture_output=True, text=True,
    ).stderr)
    return process


try:
    podman("image", "exists", IMAGE)
    other = create("-isolation")
    for kind in ("term", "hup", "group", "kill", "parent", "removed-checkout"):
        pod = create("-" + kind)
        with tempfile.TemporaryFile(mode="w+") as output, tempfile.TemporaryDirectory() as checkout:
            script = pathlib.Path(checkout) / "lifecycle.py"
            script.write_text(pathlib.Path(SCRIPT).read_text())
            launcher = None
            if kind == "parent":
                pidfile = pathlib.Path(checkout) / "owner.pid"
                launcher = subprocess.Popen(
                    [sys.executable, "-c",
                     "import pathlib, subprocess, sys, time; "
                     "p = subprocess.Popen(sys.argv[2:]); "
                     "pathlib.Path(sys.argv[1]).write_text(str(p.pid)); "
                     "time.sleep(120)",
                     str(pidfile), sys.executable, str(script), "own", pod,
                     "podman", "pod", "start", pod],
                    start_new_session=True, stdout=output, stderr=output,
                )
                owners.append(launcher)
                until(pidfile.exists)
                owner_pid = int(pidfile.read_text())
                time.sleep(1)
            else:
                process = owner(pod, output, str(script))
            duplicate = subprocess.run(
                [sys.executable, SCRIPT, "own", pod, "true"], capture_output=True, text=True,
            )
            assert duplicate.returncode != 0 and "active lifecycle" in duplicate.stderr
            if kind == "group":
                os.killpg(process.pid, signal.SIGTERM)
            elif kind == "hup":
                process.send_signal(signal.SIGHUP)
            elif kind == "parent":
                os.kill(owner_pid, 0)
                launcher.kill()
                launcher.wait(timeout=5)
            elif kind == "kill":
                process.kill()
            elif kind == "removed-checkout":
                script.unlink()
                os.rmdir(checkout)
                process.kill()
            else:
                process.send_signal(signal.SIGTERM)
            if launcher is None:
                process.wait(timeout=5)
            until(lambda: not running(pod))
            assert running(other), "Unrelated pod was stopped"
            podman("pod", "start", pod)
            assert podman("exec", pod + "-work", "cat", "/data/sentinel") == "preserved"
            podman("pod", "stop", "--time", "1", pod)
            output.seek(0)
            print(kind + ": stopped exact pod, retained volume, isolated other pod")
    print("Real Podman foreground lifecycle checks passed.")
finally:
    for process in owners:
        if process.poll() is None:
            process.terminate()
            process.wait(timeout=5)
    for pod in pods:
        if podman("pod", "inspect", pod, "--format",
                  '{{index .Labels "frontman.lifecycle-test"}}') == PREFIX:
            podman("pod", "rm", "--force", pod)
    for volume in volumes:
        if podman("volume", "inspect", volume, "--format",
                  '{{index .Labels "frontman.lifecycle-test"}}') == PREFIX:
            podman("volume", "rm", volume)
