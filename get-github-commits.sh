#!/bin/bash

GITHUB_API_ENDPOINT=${GITHUB_API_ENDPOINT:-"https://api.github.com/search/"}
GIT_HUB_HEADER=${GIT_HUB_HEADER:-"Accept: application/vnd.github.cloak-preview+json"}
COMMITS_URL_ENDPOINT="commits"

FROM_DATE=${FROM_DATE:-"2020-09-01"}
declare -a TEAM_MEMBER_LIST=("huikang" "ronensc" "eranra" "pmoogi-redhat" "ajaygupta978" "Red-GV")
SKIP_PROJECTS='"argo-rollouts"|"argo-helm"|"test"|"rollouts-demo"|"kubernetes_julio"|"Kubernetes-git"|"kubernetes-dqlite"|"k8s"|"skydive"|"skydive-ui"|"apps"'

query_commits_for_user() {
    GIT_HUB_USER=$1
    PAGE=1
    unset COMMITS_PER_REPO
    while : ; do
      PAGE_COMMITS_PER_REPO="$(curl -H "$GIT_HUB_HEADER" -s "$GITHUB_API_ENDPOINT"$COMMITS_URL_ENDPOINT"?q=author:$GIT_HUB_USER%20author-date:>$FROM_DATE&per_page=100&page=$PAGE" | jq '.items[].repository.name')"
      PAGE_COMMITS_PER_REPO=$(echo "$PAGE_COMMITS_PER_REPO"|sed -E 's/'"$SKIP_PROJECTS"'//g')
      API_CALLS_COUNT=$(( API_CALLS_COUNT + 1 ))
      if (( API_CALLS_COUNT > 9 )); then
        echo "Waiting 60 seconds for github API to allow more calls"
        sleep 60
        API_CALLS_COUNT=0
      fi
      [ -z "$PAGE_COMMITS_PER_REPO" ] && break
      COMMITS_PER_REPO=$(echo -e "$COMMITS_PER_REPO\n$PAGE_COMMITS_PER_REPO\n")
      PAGE=$(( PAGE + 1 ))
    done
    COMMITS_PER_REPO=$(echo "$COMMITS_PER_REPO" | sed '/^[[:space:]]*$/d')
}

get_commits() {
  unset TOTAL_COMMITS_PER_REPO
  API_CALLS_COUNT=0

  for GIT_HUB_USER in "${TEAM_MEMBER_LIST[@]}"; do
    query_commits_for_user "$GIT_HUB_USER"
    COMMITS_PER_REPO_COUNTS=$(echo "$COMMITS_PER_REPO" | sort | uniq -c | sort -nr)
    echo -e "Number of commits for user $GIT_HUB_USER from $FROM_DATE is:\n\n$COMMITS_PER_REPO_COUNTS\n\n"
    TOTAL_COMMITS_PER_REPO=$(echo -e "$TOTAL_COMMITS_PER_REPO\n$COMMITS_PER_REPO\n")
  done

  TOTAL_COMMITS_PER_REPO=$(echo "$TOTAL_COMMITS_PER_REPO" | sed '/^[[:space:]]*$/d')
  TOTAL_COMMITS_PER_REPO_COUNTS=$(echo "$TOTAL_COMMITS_PER_REPO" | sort | uniq -c | sort -nr)
  TOTAL_COMMITS=$(echo "$TOTAL_COMMITS_PER_REPO" | wc -l)
  TOTAL_PROJECTS=$(echo "$TOTAL_COMMITS_PER_REPO_COUNTS" | wc -l)
  echo -e "Total Number of commits for all users is:\n\n$TOTAL_COMMITS_PER_REPO_COUNTS\n\n"
  echo -e "There are in total $TOTAL_COMMITS commits in $TOTAL_PROJECTS projects (starting from $FROM_DATE)"
}


main() {
    get_commits
    exit 0
}

main