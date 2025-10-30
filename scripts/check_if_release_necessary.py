import json
import sys
import requests


def main(metadata_file: str):
    with open(metadata_file, "r") as f:
        metadata = json.load(f)

    device = metadata["env"]["DEVICE_ID"]
    repo = metadata["repo"]["repo_name"]
    gos_version = metadata["env"]["GRAPHENEOS_VERSION"]

    r = requests.get(f"https://api.github.com/repos/{repo}/releases/tags/{gos_version}")
    if r.status_code == 200:
        assets = r.json()["assets"]
        for asset in assets:
            if asset["name"] == f"kernel-{device}-{gos_version}.zip":
                print(f"Release for {device} version {gos_version} already exists")
                sys.exit(2)


if __name__ == "__main__":
    main(sys.argv[1])
