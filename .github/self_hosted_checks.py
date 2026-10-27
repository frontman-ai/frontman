import json
import os
from pathlib import PurePosixPath
import subprocess
import sys


JOBS = {
    "test-swarm-ai": "swarm",
    "test-frontman-server": "server",
    "lint-frontman-server": "server",
}


def select(event, full, base=None, head=None):
    if full == "true" or event != "pull_request":
        return {"swarm": "true", "server": "true"}
    if full not in ("", "false") or not base or not head:
        raise ValueError("Missing or invalid detection inputs")
    for revision in (base, head):
        if len(revision) != 40 or any(c not in "0123456789abcdef" for c in revision):
            raise ValueError("Expected full Git commit SHA")
    changed = subprocess.check_output(
        ["git", "diff", "--name-only", "--no-renames", "-z", f"{base}...{head}", "--"]
    ).decode("utf-8").split("\0")
    selected = {"swarm": "false", "server": "false"}
    for path in filter(None, changed):
        if path.startswith("apps/frontman_server/"):
            selected["server"] = "true"
        elif (
            path.startswith(("apps/marketing/", "docs/", ".changeset/"))
            or ("/" not in path and PurePosixPath(path).suffix == ".md")
        ):
            continue
        else:
            return {"swarm": "true", "server": "true"}
    return selected


def aggregate(needs):
    detection = needs["self-hosted-changes"]
    if detection["result"] != "success":
        raise ValueError("Change detection did not succeed")
    outputs = detection["outputs"]
    for job, selection in JOBS.items():
        selected = outputs[selection]
        result = needs[job]["result"]
        if selected not in ("true", "false"):
            raise ValueError(f"Invalid selection for {job}")
        allowed = ("success",) if selected == "true" else ("success", "skipped")
        if result not in allowed:
            raise ValueError(f"{job}: selected={selected}, result={result}")


if __name__ == "__main__":
    if sys.argv[1:] == ["detect"]:
        outputs = select(
            os.environ["EVENT_NAME"],
            os.environ["FULL_VERIFICATION"],
            os.environ.get("BASE_SHA"),
            os.environ.get("HEAD_SHA"),
        )
        with open(os.environ["GITHUB_OUTPUT"], "a") as output:
            for key, value in outputs.items():
                print(f"{key}={value}", file=output)
    elif sys.argv[1:] == ["aggregate"]:
        aggregate(json.loads(os.environ["NEEDS"]))
    else:
        raise ValueError("Expected detect or aggregate")
