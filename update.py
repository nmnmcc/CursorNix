#!/usr/bin/env python3
"""Update sources.json with the latest Cursor AppImage and agent CLI."""

import json
import re
import subprocess
from pathlib import Path
from urllib.request import Request, urlopen

ROOT = Path(__file__).parent
SOURCES_FILE = ROOT / "sources.json"
INSTALL_URL = "https://cursor.com/install"
API_BASE = "https://api2.cursor.sh/updates/api/download/stable"

LINUX_PLATFORMS = {
    "x86_64-linux": "linux-x64",
    "aarch64-linux": "linux-arm64",
}


def fetch_text(url: str) -> str:
    req = Request(url, headers={"User-Agent": "cursornix-updater"})
    with urlopen(req, timeout=120) as resp:
        return resp.read().decode()


def nix_prefetch_sri(url: str) -> str:
    result = subprocess.run(
        ["nix-prefetch-url", url],
        check=True,
        capture_output=True,
        text=True,
    )
    hex_hash = result.stdout.strip().splitlines()[0]
    sri = subprocess.run(
        ["nix-hash", "--to-sri", "--type", "sha256", hex_hash],
        check=True,
        capture_output=True,
        text=True,
    )
    return sri.stdout.strip()


def api_meta(platform: str) -> dict:
    return json.loads(fetch_text(f"{API_BASE}/{platform}/cursor"))


def update_cursor(sources: dict) -> bool:
    first = api_meta(LINUX_PLATFORMS["x86_64-linux"])
    version = first["version"]
    commit_sha = first.get("commitSha")

    current = sources.get("cursor", {})
    if (
        current.get("version") == version
        and current.get("commitSha") == commit_sha
        and all(
            current.get("appimage", {}).get(system, {}).get("hash")
            for system in LINUX_PLATFORMS
        )
    ):
        return False

    appimage = {}
    for system, api_platform in LINUX_PLATFORMS.items():
        meta = api_meta(api_platform)
        if meta["version"] != version:
            raise SystemExit(
                f"Version mismatch on {system}: {meta['version']} != {version}"
            )
        url = meta["downloadUrl"]
        if not url.endswith(".AppImage"):
            raise SystemExit(f"Expected AppImage for {system}, got {url}")
        print(f"  prefetch cursor {system} {version}")
        appimage[system] = {"url": url, "hash": nix_prefetch_sri(url)}

    sources["cursor"] = {
        "version": version,
        "commitSha": commit_sha,
        "vscodeVersion": current.get("vscodeVersion"),
        "appimage": appimage,
    }
    return True


def update_agent(sources: dict) -> bool:
    install = fetch_text(INSTALL_URL)
    match = re.search(r"lab/([0-9]{4}\.[0-9]{2}\.[0-9]{2}-[0-9a-f]+)", install)
    if not match:
        raise SystemExit("Could not parse Cursor Agent release from install script")
    release = match.group(1)

    current = sources.get("agent", {}).get("version")
    if current == release:
        return False

    tarball = {}
    agent_paths = {
        "x86_64-linux": "linux/x64",
        "aarch64-linux": "linux/arm64",
    }
    for system, path in agent_paths.items():
        url = f"https://downloads.cursor.com/lab/{release}/{path}/agent-cli-package.tar.gz"
        print(f"  prefetch agent {system} {release}")
        tarball[system] = {"url": url, "hash": nix_prefetch_sri(url)}

    sources["agent"] = {"version": release, "tarball": tarball}
    return True


def main():
    sources = json.loads(SOURCES_FILE.read_text()) if SOURCES_FILE.exists() else {}

    print("Updating latest Cursor AppImage from API ...")
    cursor_changed = update_cursor(sources)

    print("Updating Cursor Agent from install script ...")
    agent_changed = update_agent(sources)

    if cursor_changed or agent_changed:
        SOURCES_FILE.write_text(json.dumps(sources, indent=2, sort_keys=True) + "\n")
        if cursor_changed:
            print(f"Wrote sources.json (cursor {sources['cursor']['version']})")
        if agent_changed:
            print(f"Wrote sources.json (agent {sources['agent']['version']})")
    else:
        print("--- up to date ---")


if __name__ == "__main__":
    main()
