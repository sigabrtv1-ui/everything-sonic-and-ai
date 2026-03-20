#!/usr/bin/env bash
# Check Azure Pipeline status for a sonic-net PR or master branch build.
# Usage:
#   ./check_pipeline.sh pr <repo> <pr_number>      - Check PR pipeline status
#   ./check_pipeline.sh build <project_id> <build_id> - Get failed tasks and logs for a build
#   ./check_pipeline.sh master <project_id> [definition_id] [top] - Recent master builds
#
# Examples:
#   ./check_pipeline.sh pr sonic-net/sonic-gnmi 626
#   ./check_pipeline.sh build be1b070f-be15-4154-aade-b1d3bfb17054 1065782
#   ./check_pipeline.sh master be1b070f-be15-4154-aade-b1d3bfb17054

set -euo pipefail

AZURE_ORG="https://dev.azure.com/mssonic"

case "${1:-}" in
  pr)
    REPO="${2:?Usage: $0 pr <owner/repo> <pr_number>}"
    PR="${3:?Usage: $0 pr <owner/repo> <pr_number>}"
    echo "=== PR #$PR status for $REPO ==="
    gh pr view "$PR" --repo "$REPO" --json title,state,statusCheckRollup | jq '{
      title: .title,
      state: .state,
      checks: [.statusCheckRollup[] | {name, status, conclusion, detailsUrl}]
    }'
    # Extract Azure build IDs
    echo ""
    echo "=== Azure Build IDs ==="
    gh pr view "$PR" --repo "$REPO" --json statusCheckRollup | jq -r '
      [.statusCheckRollup[] | .detailsUrl // empty | select(contains("dev.azure.com"))] 
      | map(capture("buildId=(?<id>[0-9]+)").id) | unique[]'
    ;;

  build)
    PROJECT="${2:?Usage: $0 build <project_id> <build_id>}"
    BUILD="${3:?Usage: $0 build <project_id> <build_id>}"
    echo "=== Failed tasks for build $BUILD ==="
    TIMELINE=$(curl -s "$AZURE_ORG/$PROJECT/_apis/build/builds/$BUILD/timeline?api-version=7.0")
    echo "$TIMELINE" | jq '[.records[] | select(.result == "failed" and .type == "Task") | {name, log: .log.url}]'
    
    echo ""
    echo "=== Failure logs (last 60 lines each) ==="
    LOG_URLS=$(echo "$TIMELINE" | jq -r '[.records[] | select(.result == "failed" and .type == "Task") | .log.url // empty] | .[]')
    for url in $LOG_URLS; do
      echo "--- $(echo "$TIMELINE" | jq -r --arg url "$url" '[.records[] | select(.log.url == $url)][0].name') ---"
      curl -s "$url" | tail -60
      echo ""
    done
    ;;

  master)
    PROJECT="${2:?Usage: $0 master <project_id> [definition_id] [top]}"
    DEF_ID="${3:-}"
    TOP="${4:-5}"
    if [ -z "$DEF_ID" ]; then
      echo "=== Pipeline definitions ==="
      curl -s "$AZURE_ORG/$PROJECT/_apis/build/definitions?api-version=7.0" | jq '.value[] | {id, name}'
    else
      echo "=== Last $TOP master builds for definition $DEF_ID ==="
      curl -s "$AZURE_ORG/$PROJECT/_apis/build/builds?definitions=$DEF_ID&branchName=refs/heads/master&\$top=$TOP&api-version=7.0" \
        | jq '.value[] | {id, buildNumber, status, result, startTime, finishTime}'
    fi
    ;;

  *)
    echo "Usage:"
    echo "  $0 pr <owner/repo> <pr_number>              - Check PR pipeline status"
    echo "  $0 build <project_id> <build_id>             - Get failed tasks and logs"
    echo "  $0 master <project_id> [definition_id] [top] - Recent master builds"
    exit 1
    ;;
esac
