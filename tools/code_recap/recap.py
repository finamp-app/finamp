import json
from extract_history import main
from datetime import datetime

start = datetime.fromisoformat("2025-01-01T00:00:00+01:00")
end = datetime.fromisoformat("2025-12-31T23:59:59+01:00")

# (name, alias) -> if a commit is named with the alias, it will be replaced with the name
merge = [("Floschy", "flloschy"), ("herobrine1st", "HeroBrine1st Erquilenne")]

def isSpam(path):
    if path.endswith(".g.dart"): return True
    if path.endswith(".gen.dart"): return True
    if path == "pubspec.yaml": return True
    if path == "pubspec.lock": return True
    return path.endswith(".g.dart")
def isTranslation(path):
    if path.endswith(".arb"): return True
    return False
def dateBefore(x):
    return x < start
def dateInside(x):
    return x >= start


commitsNoTranslations = []
commitsOnlyTranslations = []
allCommits = []

data = json.load(open("./repo_history.json", "r"))
# data = main()
for commit in data:
    commit["date"] = datetime.fromisoformat(commit["date"])
    if commit["date"] > end:
        continue
    if commit["author"] == "Weblate (bot)":
        continue
 

    if commit.get("name"):
        commit["author"] = commit["name"]
    else:
        for (a, b) in merge:
            if commit["author"] == b:
                commit["author"] = a
                break

    commit["total_additions"] = sum([f["additions"] for f in commit["files"]])
    commit["total_deletions"] = sum([f["additions"] for f in commit["files"]])
    commit["total_changes"] = commit["total_additions"] + commit["total_deletions"]
    allCommits.append(commit)

    if not "weblate" in commit["message"].lower():
        noTranslationCommit = commit.copy()
        noTranslationCommit["files"] = [ f for f in commit["files"] if not isTranslation(f["path"]) and not isSpam(f["path"]) ]
        noTranslationCommit["total_additions"] = sum([f["additions"] for f in noTranslationCommit["files"]])
        noTranslationCommit["total_deletions"] = sum([f["additions"] for f in noTranslationCommit["files"]])
        noTranslationCommit["total_changes"] = noTranslationCommit["total_additions"] + noTranslationCommit["total_deletions"]
        if len(noTranslationCommit["files"]) >= 1:
            commitsNoTranslations.append(noTranslationCommit)

    onlyTranslationCommit = commit.copy()
    onlyTranslationCommit["files"] = [ f for f in commit["files"] if isTranslation(f["path"]) and not isSpam(f["path"]) ]
    if len(onlyTranslationCommit["files"]) >= 1:
        onlyTranslationCommit["total_additions"] = sum([f["additions"] for f in onlyTranslationCommit["files"]])
        onlyTranslationCommit["total_deletions"] = sum([f["additions"] for f in onlyTranslationCommit["files"]])
        onlyTranslationCommit["total_changes"] = onlyTranslationCommit["total_additions"] + onlyTranslationCommit["total_deletions"]
        commitsOnlyTranslations.append(onlyTranslationCommit.copy())


translateCommitsBefore = [commit for commit in commitsOnlyTranslations if dateBefore(commit["date"])]
translateCommitsWithin = [commit for commit in commitsOnlyTranslations if dateBefore(commit["date"])]
notTranslationCommitsBefore = [commit for commit in commitsNoTranslations if dateBefore(commit["date"])]
notTranslationCommitsWithin = [commit for commit in commitsNoTranslations if dateInside(commit["date"])]
allCommitsBefore = [commit for commit in allCommits if dateBefore(commit["date"])]
allCommitsWithin = [commit for commit in allCommits if dateInside(commit["date"])]


allAuthors = set([commit["author"] for commit in allCommits])
authorsBefore = set([commit["author"] for commit in allCommits if dateBefore(commit["date"])])
authorsWithin = set([commit["author"] for commit in allCommits if dateInside(commit["date"])])
newAuthors = authorsWithin.difference(authorsBefore)


pullRequestsBefore = [commit for commit in allCommitsBefore if commit["is_merge"]]
pullRequestsWithin = [commit for commit in allCommitsWithin if commit["is_merge"]]

changesPerPullRequestsBefore = [commit["total_changes"] for commit in allCommitsBefore if commit["is_merge"]]
changesPerPullRequestsWithin = [commit["total_changes"] for commit in allCommitsWithin if commit["is_merge"]]

additionsBefore = [commit["total_additions"] for commit in notTranslationCommitsBefore]
additionsWithin = [commit["total_additions"] for commit in notTranslationCommitsWithin]
additions = additionsBefore + additionsWithin

deletionsBefore = [commit["total_deletions"] for commit in notTranslationCommitsBefore]
deletionsWithin = [commit["total_deletions"] for commit in notTranslationCommitsWithin]
deletions = deletionsBefore + deletionsWithin

translationChangesBefore = [commit["total_changes"] for commit in translateCommitsBefore]
translationChangesWithin = [commit["total_changes"] for commit in translateCommitsWithin]

commitMessagesWithin = [len(commit["message"].split(" ")) for commit in allCommitsWithin]

changesPerNewAuthor = [(author, sum([commit["total_changes"] for commit in notTranslationCommitsWithin if commit["author"] == author])) for author in newAuthors]
commitsPerNewAuthor = [(author, len([commit for commit in notTranslationCommitsWithin if commit["author"] == author])) for author in newAuthors]
changesPerNewAuthor.sort(key=lambda x: -x[1])
commitsPerNewAuthor.sort(key=lambda x: -x[1])

changesPerAuthor = [(author, sum([commit["total_changes"] for commit in commitsNoTranslations if commit["author"] == author])) for author in allAuthors]
commitsPerAuthor = [(author, len([commit for commit in commitsNoTranslations if commit["author"] == author])) for author in allAuthors]
changesPerAuthor.sort(key=lambda x: -x[1])
commitsPerAuthor.sort(key=lambda x: -x[1])

changesPerTranslationNewAuthor = [(author, sum([commit["total_changes"] for commit in commitsOnlyTranslations if commit["author"] == author])) for author in newAuthors]
changesPerTranslationAllAuthor = [(author, sum([commit["total_changes"] for commit in commitsOnlyTranslations if commit["author"] == author])) for author in allAuthors]
changesPerTranslationNewAuthor.sort(key=lambda x: -x[1])
changesPerTranslationAllAuthor.sort(key=lambda x: -x[1])




markdown = f"""
# These are the statistics from {start} to {end}:

| Scope         | Description           | Value                                                                                                                       |
|:--------------|:----------------------|:----------------------------------------------------------------------------------------------------------------------------|
| **Timeframe** | Commits               |  {(len(notTranslationCommitsWithin)):,}                                                                                     |
| **Timeframe** | New Authors           |  {(len(newAuthors)):,}                                                                                                      |
| **Timeframe** | + Additions           |  {(sum(additionsWithin)):,} lines                                                                                           |
| **Timeframe** | - Deletions           |  {(sum(deletionsWithin)):,} lines                                                                                           |
| **Timeframe** | Additions per Commit  |  {round(sum(additionsWithin) / len(notTranslationCommitsWithin)):,} lines                                                   |
| **Timeframe** | Deletions per Commit  |  {round(sum(deletionsWithin) / len(notTranslationCommitsWithin)):,} lines                                                   |
| **Timeframe** | Total Difference      | +{(sum(additionsWithin) - sum(deletionsWithin)):,} lines                                                                    |
| **Timeframe** | Commit Message        |  {(sum(commitMessagesWithin)):,} words                                                                                      |
| **Timeframe** | Pull Requests Merged  |  {len(pullRequestsWithin):,}                                                                                                |
| **Timeframe** | Changes Per PR        |  {round(sum(changesPerPullRequestsWithin) / len(pullRequestsWithin)):,}                                                     |
| **Timeframe** | Translation Changes   |  {sum(translationChangesWithin):,}                                                       |
|               |                       |                                                                                                                             |
| *(Lifetime)*  | Commits               |  {(len(notTranslationCommitsBefore) + len(notTranslationCommitsWithin)):,}                                                  |
| *(Lifetime)*  | Authors               |  {(len(authorsBefore) + len(newAuthors)):,}                                                                                 |
| *(Lifetime)*  | + Additions           |  {(sum(additionsWithin) + sum(additionsBefore)):,} lines                                                                    |
| *(Lifetime)*  | - Deletions           |  {(sum(deletionsWithin) + sum(deletionsBefore)):,} lines                                                                    |
| *(Lifetime)*  | Additions per Commit  |  {round(sum(deletions) / len(commitsNoTranslations)):,} lines                                                               |
| *(Lifetime)*  | Deletions per Commit  |  {round(sum(deletions) / len(commitsNoTranslations)):,} lines                                                               |
| *(Lifetime)*  | Pull Requests Merged  |  {len(pullRequestsBefore + pullRequestsWithin):,}                                                                           |
| *(Lifetime)*  | Changes Per PR        |  {round(sum(changesPerPullRequestsBefore + changesPerPullRequestsWithin) / len(pullRequestsBefore + pullRequestsWithin)):,} |
| *(Lifetime)*  | Translation Changes   |  {(sum(translationChangesBefore) + sum(translationChangesWithin)):,}                                                        |

_____

## New Code Authors ranked by changes:

| Nr | Name                        | Changes                       |     | Nr | Name                        | Changes                       |
|:---|:----------------------------|:------------------------------|:---:|:---|:----------------------------|:------------------------------|
| 1. | {changesPerNewAuthor[0][0]} | {changesPerNewAuthor[0][1]:,} |     | 6. | {changesPerNewAuthor[5][0]} | {changesPerNewAuthor[5][1]:,} |
| 2. | {changesPerNewAuthor[1][0]} | {changesPerNewAuthor[1][1]:,} |     | 7. | {changesPerNewAuthor[6][0]} | {changesPerNewAuthor[6][1]:,} |
| 3. | {changesPerNewAuthor[2][0]} | {changesPerNewAuthor[2][1]:,} |     | 8. | {changesPerNewAuthor[7][0]} | {changesPerNewAuthor[7][1]:,} |
| 4. | {changesPerNewAuthor[3][0]} | {changesPerNewAuthor[3][1]:,} |     | 9. | {changesPerNewAuthor[8][0]} | {changesPerNewAuthor[8][1]:,} |
| 5. | {changesPerNewAuthor[4][0]} | {changesPerNewAuthor[4][1]:,} |     | 10.| {changesPerNewAuthor[9][0]} | {changesPerNewAuthor[9][1]:,} |



## New Code Authors ranked by commits:

| Nr | Name                        | Commits                       |     | Nr | Name                        | Commits                       |
|:---|:----------------------------|:------------------------------|:---:|:---|:----------------------------|:------------------------------|
| 1. | {commitsPerNewAuthor[0][0]} | {commitsPerNewAuthor[0][1]:,} |     | 6. | {commitsPerNewAuthor[5][0]} | {commitsPerNewAuthor[5][1]:,} |
| 2. | {commitsPerNewAuthor[1][0]} | {commitsPerNewAuthor[1][1]:,} |     | 7. | {commitsPerNewAuthor[6][0]} | {commitsPerNewAuthor[6][1]:,} |
| 3. | {commitsPerNewAuthor[2][0]} | {commitsPerNewAuthor[2][1]:,} |     | 8. | {commitsPerNewAuthor[7][0]} | {commitsPerNewAuthor[7][1]:,} |
| 4. | {commitsPerNewAuthor[3][0]} | {commitsPerNewAuthor[3][1]:,} |     | 9. | {commitsPerNewAuthor[8][0]} | {commitsPerNewAuthor[8][1]:,} |
| 5. | {commitsPerNewAuthor[4][0]} | {commitsPerNewAuthor[4][1]:,} |     | 10.| {commitsPerNewAuthor[9][0]} | {commitsPerNewAuthor[9][1]:,} |


## New Translators ranked by changes:

| Nr | Name                                   | Commits                                  |     | Nr | Name                                   | Commits                                  |
|:---|:---------------------------------------|:-----------------------------------------|:---:|:---|:---------------------------------------|:-----------------------------------------|
| 1. | {changesPerTranslationNewAuthor[0][0]} | {changesPerTranslationNewAuthor[0][1]:,} |     | 6. | {changesPerTranslationNewAuthor[5][0]} | {changesPerTranslationNewAuthor[5][1]:,} |
| 2. | {changesPerTranslationNewAuthor[1][0]} | {changesPerTranslationNewAuthor[1][1]:,} |     | 7. | {changesPerTranslationNewAuthor[6][0]} | {changesPerTranslationNewAuthor[6][1]:,} |
| 3. | {changesPerTranslationNewAuthor[2][0]} | {changesPerTranslationNewAuthor[2][1]:,} |     | 8. | {changesPerTranslationNewAuthor[7][0]} | {changesPerTranslationNewAuthor[7][1]:,} |
| 4. | {changesPerTranslationNewAuthor[3][0]} | {changesPerTranslationNewAuthor[3][1]:,} |     | 9. | {changesPerTranslationNewAuthor[8][0]} | {changesPerTranslationNewAuthor[8][1]:,} |
| 5. | {changesPerTranslationNewAuthor[4][0]} | {changesPerTranslationNewAuthor[4][1]:,} |     | 10.| {changesPerTranslationNewAuthor[9][0]} | {changesPerTranslationNewAuthor[9][1]:,} |


## All-time Code Authors ranked by changes:

| Nr | Name                     | Changes                    |     | Nr | Name                     | Changes                    |
|:---|:-------------------------|:---------------------------|:---:|:---|:-------------------------|:---------------------------|
| 1. | {changesPerAuthor[0][0]} | {changesPerAuthor[0][1]:,} |     | 6. | {changesPerAuthor[5][0]} | {changesPerAuthor[5][1]:,} |
| 2. | {changesPerAuthor[1][0]} | {changesPerAuthor[1][1]:,} |     | 7. | {changesPerAuthor[6][0]} | {changesPerAuthor[6][1]:,} |
| 3. | {changesPerAuthor[2][0]} | {changesPerAuthor[2][1]:,} |     | 8. | {changesPerAuthor[7][0]} | {changesPerAuthor[7][1]:,} |
| 4. | {changesPerAuthor[3][0]} | {changesPerAuthor[3][1]:,} |     | 9. | {changesPerAuthor[8][0]} | {changesPerAuthor[8][1]:,} |
| 5. | {changesPerAuthor[4][0]} | {changesPerAuthor[4][1]:,} |     | 10.| {changesPerAuthor[9][0]} | {changesPerAuthor[9][1]:,} |


## All-time Code Authors ranked by commits:

| Nr | Name                     | Commits                    |     | Nr | Name                     | Commits                    |
|:---|:-------------------------|:---------------------------|:---:|:---|:-------------------------|:---------------------------|
| 1. | {commitsPerAuthor[0][0]} | {commitsPerAuthor[0][1]:,} |     | 6. | {commitsPerAuthor[5][0]} | {commitsPerAuthor[5][1]:,} |
| 2. | {commitsPerAuthor[1][0]} | {commitsPerAuthor[1][1]:,} |     | 7. | {commitsPerAuthor[6][0]} | {commitsPerAuthor[6][1]:,} |
| 3. | {commitsPerAuthor[2][0]} | {commitsPerAuthor[2][1]:,} |     | 8. | {commitsPerAuthor[7][0]} | {commitsPerAuthor[7][1]:,} |
| 4. | {commitsPerAuthor[3][0]} | {commitsPerAuthor[3][1]:,} |     | 9. | {commitsPerAuthor[8][0]} | {commitsPerAuthor[8][1]:,} |
| 5. | {commitsPerAuthor[4][0]} | {commitsPerAuthor[4][1]:,} |     | 10.| {commitsPerAuthor[9][0]} | {commitsPerAuthor[9][1]:,} |

## All-time Translators ranked by changes:

| Nr | Name                                   | Commits                                  |     | Nr | Name                                   | Commits                                  |
|:---|:---------------------------------------|:-----------------------------------------|:---:|:---|:---------------------------------------|:-----------------------------------------|
| 1. | {changesPerTranslationAllAuthor[0][0]} | {changesPerTranslationAllAuthor[0][1]:,} |     | 6. | {changesPerTranslationAllAuthor[5][0]} | {changesPerTranslationAllAuthor[5][1]:,} |
| 2. | {changesPerTranslationAllAuthor[1][0]} | {changesPerTranslationAllAuthor[1][1]:,} |     | 7. | {changesPerTranslationAllAuthor[6][0]} | {changesPerTranslationAllAuthor[6][1]:,} |
| 3. | {changesPerTranslationAllAuthor[2][0]} | {changesPerTranslationAllAuthor[2][1]:,} |     | 8. | {changesPerTranslationAllAuthor[7][0]} | {changesPerTranslationAllAuthor[7][1]:,} |
| 4. | {changesPerTranslationAllAuthor[3][0]} | {changesPerTranslationAllAuthor[3][1]:,} |     | 9. | {changesPerTranslationAllAuthor[8][0]} | {changesPerTranslationAllAuthor[8][1]:,} |
| 5. | {changesPerTranslationAllAuthor[4][0]} | {changesPerTranslationAllAuthor[4][1]:,} |     | 10.| {changesPerTranslationAllAuthor[9][0]} | {changesPerTranslationAllAuthor[9][1]:,} |


(*) Please understand that these statistics are **just for fun** and dont represent serious measurements of work, invested time, or value to the project! **Any** addition helps, no matter how big.
(?) A "change" is counted as any amount of change in a line, be it addition or deletion.
"""



for _ in range(100):
    markdown = markdown.replace("  ", " ").replace("----", "---")

print(markdown)
