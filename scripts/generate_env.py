import datetime
import json
import os
import sys
import requests


def traverse_dict(d, prefix=None, env_vars=None):
    if env_vars is None:
        env_vars = {}
    if prefix is None:
        prefix = ""

    for k, v in d.items():
        if isinstance(v, dict):
            traverse_dict(v, f"{prefix}{k.upper()}_", env_vars)
        else:
            env_vars[f"{prefix}{k.upper()}"] = v

    return env_vars


def get_latest_graphene_release(device, branch):
    if os.getenv("GRAPHENEOS_VERSION"):
        return os.getenv("GRAPHENEOS_VERSION")

    r = requests.get(f"https://releases.grapheneos.org/{device}-{branch}")
    return r.text.split(" ")[0]


def get_latest_ksu_commit(branch_name):
    if os.getenv("KERNELSU_VERSION"):
        return os.getenv("KERNELSU_VERSION")

    r = requests.get(f"https://api.github.com/repos/tiann/KernelSU/commits?sha={branch_name}")
    return r.json()[0]["sha"]


def get_latest_susfs_commit(branch_name):
    if os.getenv("SUSFS_VERSION"):
        return os.getenv("SUSFS_VERSION")

    r = requests.get(f"https://gitlab.com/api/v4/projects/simonpunk%2Fsusfs4ksu/repository/commits?ref_name={branch_name}")
    return r.json()[0]["id"]


def main(device: str, repo_name: str, ref_name: str, metadata_output_dir: str):
    path = os.path.join(os.getcwd(), "devices", f"{device}.json")
    with open(path, "r") as f:
        data = json.load(f)
        env_vars = traverse_dict(data)

    if device == "dummy":
        gos_version = get_latest_graphene_release("tokay", branch=env_vars.get("GRAPHENEOS_BRANCH", "stable"))
    else:
        gos_version = get_latest_graphene_release(device, branch=env_vars.get("GRAPHENEOS_BRANCH", "stable"))
    ksu_version = get_latest_ksu_commit(env_vars.get("KERNELSU_BRANCH", "main"))
    susfs_version = get_latest_susfs_commit(env_vars.get("SUSFS_BRANCH"))

    env_vars["DEVICE_ID"] = device
    env_vars["GRAPHENEOS_VERSION"] = gos_version
    env_vars["KERNELSU_VERSION"] = ksu_version
    env_vars["SUSFS_VERSION"] = susfs_version
    env_vars["CACHE_KEY"] = f"{device}-{gos_version}-{ksu_version}-{susfs_version}-{ref_name}"

    dt = datetime.datetime.now()
    env_vars["BUILD_DATETIME"] = int(dt.timestamp())
    env_vars["BUILD_NUMBER"] = dt.strftime("%Y%m%d.%H%M%S")

    metadata_path = os.path.join(metadata_output_dir, f"build_metadata_{device}_{gos_version}.json")
    env_vars["BUILD_METADATA_FILE"] = metadata_path

    with open(metadata_path, "w") as f:
        json.dump({
            "env": env_vars,
            "repo": {
                "repo_name": repo_name,
                "ref_name": ref_name
            },
            "dependencies": {
                "gitlab": [
                    {
                        "name": "GrapheneOS",
                        "repo_name": "GrapheneOS/kernel_pixel",
                        "ref_name": gos_version
                    },
                    {
                        "name": "susfs4ksu",
                        "repo_name": "simonpunk/susfs4ksu",
                        "ref_name": susfs_version
                    }
                ],
                "github": [
                    {
                        "name": "KernelSU",
                        "repo_name": "tiann/KernelSU",
                        "ref_name": ksu_version
                    }
                ]
            }
        }, f, indent=4)

    for k, v in env_vars.items():
        print(f"{k}={v}")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4])
