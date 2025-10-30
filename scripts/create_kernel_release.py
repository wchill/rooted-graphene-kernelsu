import base64
import json
import os
import sys
from typing import Literal, Union

import requests
from github import Github, Auth, GithubException
from urllib.parse import quote
from dataclasses import dataclass


@dataclass
class GitCommit:
    repo_name: str
    id: str
    short_id: str
    commit_url: str


class Dependency:
    def __init__(self, name: str, repo_name: str, ref_name: str, service: Union[Literal["gitlab"], Literal["github"]]):
        self.name = name
        self.repo_name = repo_name
        self.service = service
        self.ref_name = ref_name

    def get_latest_commit(self) -> GitCommit:
        if self.service == "gitlab":
            return self.get_latest_gitlab_commit()
        elif self.service == "github":
            return self.get_latest_github_commit()
        else:
            raise ValueError(f"Unknown service {self.service}")

    def get_latest_gitlab_commit(self) -> GitCommit:
        url = f"https://gitlab.com/api/v4/projects/{quote(self.repo_name, safe='')}/repository/commits?ref_name={self.ref_name}"
        r = requests.get(url)
        commit = r.json()[0]
        return GitCommit(
            repo_name=self.repo_name, id=commit["id"], short_id=commit["short_id"], commit_url=commit["web_url"]
        )

    def get_latest_github_commit(self) -> GitCommit:
        url = f"https://api.github.com/repos/{self.repo_name}/commits?sha={self.ref_name}"
        r = requests.get(url)
        if r.status_code >= 400:
            raise ValueError(f"Failed to get latest commit for {self.repo_name}@{self.ref_name}: {r.status_code} {r.text}")

        commit = r.json()[0]
        return GitCommit(
            repo_name=self.repo_name, id=commit["sha"], short_id=commit["sha"][:7], commit_url=commit["html_url"]
        )


def generate_changelog(src_repo: str, ota_version: str, dependencies: list[Dependency]) -> str:
    commits = [dep.get_latest_commit() for dep in dependencies]
    dependency_text = "\n\n".join([
        f"{commit.repo_name}: {commit.commit_url}" for commit in commits
    ])
    ota_version_anchor = ota_version[:-1] + "0"
    return (f"Kernel + modules for [GrapheneOS {ota_version}](https://grapheneos.org/releases#{ota_version_anchor}).\n\n"
            f"{dependency_text}\n\n"
            f"Built using {src_repo}@{ota_version}")


def generate_release_notes(github: Github, repo_name: str, ota_version: str):
    return github.get_repo(repo_name).generate_release_notes(tag_name=ota_version, target_commitish="main").body


def create_github_release(github: Github, repo_name: str, release_name: str, dependencies: list[Dependency]) -> int:
    changelog = generate_changelog(repo_name, release_name, dependencies)

    try:
        return github.get_repo(repo_name).create_git_release(
            tag=release_name,
            name=release_name,
            message=changelog,
            target_commitish="main",
        ).id
    except GithubException as e:
        if e.status == 422:
            return github.get_repo(repo_name).get_release(release_name).id
        else:
            raise


def upload_file(github: Github, repo_name: str, release_id: int, file_path: str):
    try:
        github.get_repo(repo_name).get_release(release_id).upload_asset(file_path)
    except GithubException as e:
        if e.status == 422:
            pass
        else:
            raise


def main(github_token, dependency_metadata_path, file_path):
    github = Github(auth=Auth.Token(github_token))

    dependencies = []
    with open(dependency_metadata_path, "r") as f:
        data = json.load(f)
        for service, deps in data["dependencies"].items():
            for dep in deps:
                dependencies.append(Dependency(dep["name"], dep["repo_name"], dep["ref_name"], service))
    repo_name = data["repo"]["repo_name"]
    release_name = data["env"]["GRAPHENEOS_VERSION"]

    release_id = create_github_release(github, repo_name, release_name, dependencies)
    upload_file(github, repo_name, release_id, dependency_metadata_path)
    upload_file(github, repo_name, release_id, file_path)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2], sys.argv[3])
