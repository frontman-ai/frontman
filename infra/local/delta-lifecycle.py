import fcntl
import hashlib
import json
import os
import pathlib
import signal
import subprocess
import sys
import time


def identity(pid):
    try:
        fields = pathlib.Path(f"/proc/{pid}/stat").read_text().rsplit(")", 1)[1].split()
        return None if fields[0] == "Z" else fields[19]
    except (FileNotFoundError, ProcessLookupError):
        return None


def signal_group(pid, sig):
    try:
        os.killpg(pid, sig)
    except ProcessLookupError:
        pass


def stop_pod(pod, log):
    while True:
        exists = subprocess.run(["podman", "pod", "exists", pod]).returncode
        if exists == 1:
            return
        if exists == 0 and subprocess.run(
            ["podman", "pod", "stop", "--time", "10", pod], stdout=log, stderr=log,
        ).returncode == 0:
            return
        print("Pod cleanup failed; retaining ownership and retrying.", file=log, flush=True)
        time.sleep(1)


def watchdog(owner, parent, pod, command, lock, log):
    signal.signal(signal.SIGHUP, signal.SIG_IGN)
    def terminate(signum, frame):
        raise SystemExit(128 + signum)
    signal.signal(signal.SIGTERM, terminate)
    signal.signal(signal.SIGINT, terminate)
    os.chdir("/")
    worker = None
    since = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    try:
        worker = subprocess.Popen(command, start_new_session=True, stdout=log, stderr=log)
        started = False
        while identity(owner[0]) == owner[1] and identity(parent[0]) == parent[1]:
            if os.fstat(log.fileno()).st_size > 1024 * 1024:
                log.flush()
                os.ftruncate(log.fileno(), 0)
                os.lseek(log.fileno(), 0, os.SEEK_SET)
            if worker.poll() is not None:
                if worker.returncode or started:
                    return worker.returncode
                worker = subprocess.Popen(
                    ["podman", "pod", "logs", "--follow", "--since", since, pod],
                    start_new_session=True, stdout=log, stderr=log,
                )
                started = True
            time.sleep(0.2)
    finally:
        signal.signal(signal.SIGTERM, signal.SIG_IGN)
        signal.signal(signal.SIGINT, signal.SIG_IGN)
        try:
            if worker is not None:
                signal_group(worker.pid, signal.SIGTERM)
                try:
                    worker.wait(timeout=3)
                except subprocess.TimeoutExpired:
                    pass
                signal_group(worker.pid, signal.SIGKILL)
                worker.wait()
            containers = subprocess.run(
                ["podman", "pod", "inspect", pod, "--format", "{{json .Containers}}"],
                capture_output=True, text=True,
            )
            if containers.returncode == 0:
                for container in json.loads(containers.stdout):
                    if container["Name"].endswith("-dev"):
                        try:
                            subprocess.run(
                                ["podman", "exec", container["Id"], "bash", "-c",
                                 'if [[ -s /tmp/frontman-supervisor.pid ]]; then '
                                 'kill -TERM "$(cat /tmp/frontman-supervisor.pid)" || exit; '
                                 'for ((i=0; i<100; i++)); do '
                                 '[[ -e /tmp/frontman-supervisor.pid ]] || exit 0; '
                                 'sleep 0.1; done; exit 1; fi'],
                                stdout=log, stderr=log, timeout=15,
                            )
                        except subprocess.TimeoutExpired:
                            print("Supervisor shutdown timed out; stopping exact pod.", file=log, flush=True)
        finally:
            stop_pod(pod, log)
            os.close(lock)


def main():
    mode, pod, *command = sys.argv[1:]
    directory = pathlib.Path(f"/tmp/frontman-delta-lifecycle-{os.getuid()}")
    directory.mkdir(mode=0o700, exist_ok=True)
    if directory.stat().st_uid != os.getuid() or directory.stat().st_mode & 0o077:
        sys.exit("Unsafe lifecycle directory")
    key = hashlib.sha256(pod.encode()).hexdigest()
    lock = os.open(directory / (key + ".lock"), os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        sys.exit(f"{pod} already has an active lifecycle operation; stop its foreground owner first.")
    if mode == "guard":
        sys.exit(subprocess.call(command, pass_fds=(lock,)))
    pod_id = subprocess.check_output(
        ["podman", "pod", "inspect", pod, "--format", "{{.Id}}"], text=True
    ).strip()
    owner = (os.getpid(), identity(os.getpid()))
    parent = (os.getppid(), identity(os.getppid()))
    log_path = directory / (key + ".log")
    log = open(log_path, "w")
    source = pathlib.Path(__file__).read_text()
    process = subprocess.Popen(
        [sys.executable, "-c", source, "watchdog", str(owner[0]), owner[1],
         str(parent[0]), parent[1], pod_id, str(lock), *command],
        pass_fds=(lock,), start_new_session=True, stdin=subprocess.DEVNULL,
        stdout=log, stderr=log,
    )
    log.close()
    log = open(log_path, errors="replace")
    log_path.unlink()
    os.close(lock)
    def terminate(signum, frame):
        raise SystemExit(128 + signum)
    for sig in (signal.SIGTERM, signal.SIGINT, signal.SIGHUP):
        signal.signal(sig, terminate)
    try:
        while process.poll() is None:
            if log.tell() > os.fstat(log.fileno()).st_size:
                log.seek(0)
            text = log.read()
            if text:
                print(text, end="", flush=True)
            time.sleep(0.2)
        print(log.read(), end="", flush=True)
        return process.returncode
    finally:
        log.close()


if __name__ == "__main__":
    if sys.argv[1] == "watchdog":
        _, _, owner_pid, owner_time, parent_pid, parent_time, pod, lock, *command = sys.argv
        sys.exit(watchdog((int(owner_pid), owner_time), (int(parent_pid), parent_time),
                          pod, command, int(lock), sys.stdout))
    else:
        sys.exit(main())
