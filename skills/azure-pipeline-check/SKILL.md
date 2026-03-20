---
name: azure-pipeline-check
description: >
  Check Azure DevOps pipeline status and logs for sonic-net repos. Use when: (1) checking CI/pipeline status for a specific PR, (2) investigating build failures or test failures in Azure Pipelines, (3) checking master/main branch CI health, (4) fetching detailed failure logs from Azure DevOps. Works with sonic-net/sonic-gnmi and other sonic-net repos using mssonic Azure org. NOT for: GitHub Actions checks (use gh CLI directly), non-Azure CI systems.
---

# Azure Pipeline Check

Check Azure DevOps pipeline status and failure logs for sonic-net PRs or branches.

## Prerequisites

- `gh` CLI authenticated (for PR check lookups)
- `curl` and `jq` available
- The Azure DevOps org must be publicly accessible (mssonic org is public)

## Workflow

### 1. Get Pipeline Status for a PR

```bash
gh pr view <PR_NUMBER> --repo <OWNER/REPO> --json statusCheckRollup,title,state,headRefName
```

Parse `statusCheckRollup` entries. Azure checks have `detailsUrl` pointing to `dev.azure.com`. Extract the `buildId` from the URL:
```
https://dev.azure.com/mssonic/<PROJECT_ID>/_build/results?buildId=<BUILD_ID>
```

### 2. Get Pipeline Status for Master/Main Branch

```bash
# List recent builds for a pipeline definition
curl -s "https://dev.azure.com/mssonic/<PROJECT_ID>/_apis/build/builds?definitions=<DEFINITION_ID>&branchName=refs/heads/master&\$top=5&api-version=7.0" | jq '.value[] | {id, buildNumber, status, result, startTime, finishTime}'
```

To find `DEFINITION_ID`, check a known build's timeline or use:
```bash
curl -s "https://dev.azure.com/mssonic/<PROJECT_ID>/_apis/build/definitions?api-version=7.0" | jq '.value[] | {id, name}'
```

Known project IDs:
- sonic-gnmi: `be1b070f-be15-4154-aade-b1d3bfb17054`

### 3. Find Failed Jobs/Tasks

```bash
curl -s "https://dev.azure.com/mssonic/<PROJECT_ID>/_apis/build/builds/<BUILD_ID>/timeline?api-version=7.0" \
  | jq '[.records[] | select(.result == "failed") | {name, id, type, result, log: .log.url}]'
```

This returns failed jobs, phases, stages, and tasks with their log URLs.

### 4. Fetch Failure Logs

```bash
curl -s "<LOG_URL>" | tail -100
```

Log URLs come from the timeline response `.log.url` field. Use `tail` to get the relevant error output at the end.

**Tip:** Focus on `type: "Task"` entries for the actual error. `type: "Job"`, `"Phase"`, and `"Stage"` entries are parent containers.

### 5. Common Patterns

**Go build failures:** Look for `go.mod` parse errors, missing dependencies, or version mismatches.

**Test failures:** Look for `FAIL` lines with package names. The summary usually appears near the end: `DONE X tests, Y skipped, Z failure`.

**Pure Package CI vs Build build:** sonic-gnmi has two main jobs — "Pure Package CI" runs Go tests without swss dependencies, "Build build" does the full Debian package build.

## Notes

- Azure DevOps renders logs client-side in the browser, so `web_fetch` won't work — always use the REST API.
- No authentication needed for the mssonic org (public).
- The `timeline` API is the key entry point — it gives you the full build tree with log URLs.
