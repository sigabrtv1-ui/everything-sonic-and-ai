---
name: azure-pipeline-check
description: >
  Check Azure DevOps pipeline status and logs for sonic-net repos. Use when: (1) checking CI/pipeline status for a specific PR, (2) investigating build failures in Azure Pipelines, (3) checking master/main branch CI health. Works with sonic-net repos using mssonic Azure org. NOT for: GitHub Actions checks, non-Azure CI systems.
---

# Azure Pipeline Check

## Get Pipeline Status for a PR

```bash
gh pr view <PR_NUMBER> --repo <OWNER/REPO> --json statusCheckRollup,title,state,headRefName
```

Azure checks have `detailsUrl` containing `dev.azure.com`. Extract `buildId` from the URL.

## Get Recent Master Builds

```bash
curl -s "https://dev.azure.com/mssonic/<PROJECT_ID>/_apis/build/builds?definitions=<DEF_ID>&branchName=refs/heads/master&\$top=5&api-version=7.0" | jq '.value[] | {id, buildNumber, status, result, startTime, finishTime}'
```

To find definition IDs:
```bash
curl -s "https://dev.azure.com/mssonic/<PROJECT_ID>/_apis/build/definitions?api-version=7.0" | jq '.value[] | {id, name}'
```

## Find Failed Jobs and Fetch Logs

```bash
# Get failed tasks
curl -s "https://dev.azure.com/mssonic/<PROJECT_ID>/_apis/build/builds/<BUILD_ID>/timeline?api-version=7.0" \
  | jq '[.records[] | select(.result == "failed" and .type == "Task") | {name, log: .log.url}]'

# Fetch a task's log
curl -s "<LOG_URL>" | tail -100
```

## Known Project IDs

- sonic-gnmi: `be1b070f-be15-4154-aade-b1d3bfb17054`

## Notes

- Azure DevOps renders logs client-side — always use the REST API, not `web_fetch`.
- No auth needed for the mssonic org (public).
- Helper script: `scripts/check_pipeline.sh` — run without args for usage.
