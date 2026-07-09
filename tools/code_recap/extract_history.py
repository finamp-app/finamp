import subprocess
import json
import os
import re
import sys
import requests
import time
from datetime import datetime

# Path of the github repo
PATH = "./"

# Request the real username (not displayname) of an user
# (this will take very long)
fetchGithubUsername = False

# If you have a vpn, you can enable this to increase speed
# The tradeoff is that you need to monitor the script and manually
# Change VPN servers when "(ip got blocked)" gets printed
iHaveVPN = False








user_cache = {}
def get_github_username_from_commit(repo_path, commit_hash, displayname):
    if not fetchGithubUsername:
        return displayname

    if displayname in user_cache.keys():
        return user_cache[displayname]

    url = f"https://api.github.com/repos/{repo_path}/commits/{commit_hash}"
    headers = {}


    # Default rate limit is 60/h, with an VPN we can spam a bit harder
    requestsPerMinute = 60/300 if iHaveVPN else 60

    try:
        response = requests.get(url, headers=headers)
        while response.status_code == 429 or response.status_code == 403:
            response = requests.get(url, headers=headers)
            waitTime = 20 if iHaveVPN else 120
            print(f"Ratelimited... Waiting {waitTime} seconds")
            if (response.status_code == 403):
                print("  (ip got blocked)")
            time.sleep(waitTime) # wait one minute to recover
        time.sleep(requestsPerMinute)

        if response.status_code == 200:
            data = response.json()
            # GitHub returns a 'author' object if the commit is linked to an account
            if data.get("author"):
                username = data["author"]["login"]
                print("Found " + username + " for " + displayname)
                user_cache[displayname] = username
                return username
    except Exception as e:
        print(f"Error fetching API: {e}")

    return displayname

def run_git_command(args, cwd):
    try:
        result = subprocess.run(
            ['git'] + args,
            cwd=cwd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            encoding='utf-8',
            errors='replace'
        )
        if result.returncode != 0:
            print(f"Error running git command: {result.stderr}", file=sys.stderr)
            return None
        return result.stdout.strip()
    except FileNotFoundError:
        print("Error: 'git' command not found. Please ensure Git is installed.", file=sys.stderr)
        sys.exit(1)

def get_commit_stats(commit_hash, cwd):
    output = run_git_command(['show', '--numstat', '--format=', commit_hash], cwd)

    files_changed = []
    total_additions = 0
    total_deletions = 0

    if not output:
        return files_changed

    for line in output.split('\n'):
        if not line.strip():
            continue

        parts = line.split(maxsplit=2)
        if len(parts) < 3:
            continue

        additions_raw, deletions_raw, file_path = parts

        if additions_raw == '-' or deletions_raw == '-':
            additions = 0
            deletions = 0
        else:
            additions = int(additions_raw)
            deletions = int(deletions_raw)

        files_changed.append({
            "path": file_path,
            "additions": additions,
            "deletions": deletions,
            "total_changes": additions + deletions
        })

    return files_changed

def main():
    if not os.path.exists(os.path.join(PATH, ".git")):
        print(f"Error: No git repository found at {PATH}")
        return

    hashes_output = run_git_command(['log', '--pretty=format:%H'], PATH)
    if not hashes_output:
        print("No commits found.")
        return

    commit_hashes = hashes_output.split('\n')
    history_data = []

    total_commits = len(commit_hashes)
    print(f"Found {total_commits} commits. Extracting details...")

    for i, commit_hash in enumerate(commit_hashes):
        if i % 10 == 0:
            print(f"Processing {i}/{total_commits} ({round(i / total_commits * 100, 0)}%)... [{len(user_cache.keys())} cache size]  ") # end="\r")

        meta_cmd = [
            'show', 
            '-s', 
            '--format=%H%n%an%n%ae%n%cn%n%ce%n%aI%n%P%n%s%n%b', 
            commit_hash
        ]
        meta_output = run_git_command(meta_cmd, PATH)

        if not meta_output:
            continue

        lines = meta_output.split('\n')
        c_hash = lines[0]
        a_name = lines[1]
        a_email = lines[2]
        c_name = lines[3]
        c_email = lines[4]
        date_iso = lines[5]
        parents = lines[6].split()
        subject = lines[7]

        body = "\n".join(lines[8:])

        is_merge = len(parents) > 1

        files = get_commit_stats(c_hash, PATH)

        commit_entry = {
            "hash": c_hash,
            "author": a_name,
            "date": date_iso,
            "is_merge": is_merge,
            "message": subject,
            "files": files
        }

        if fetchGithubUsername:
            commit_entry["name"] = get_github_username_from_commit("jmshrv/finamp", c_hash, a_name)

        history_data.append(commit_entry)


    output_file = "repo_history.json"
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(history_data, f, indent=2)
    print(f"\nDone! {len(history_data)} commits parsed")

    return history_data

if __name__ == "__main__":
    main()
