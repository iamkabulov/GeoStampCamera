# PR Review Agent — test session 2 (GitHub MCP)

Captured on 2026-11-02 with Claude Code 2.1.316 in the repository root, so the agent loads `CLAUDE.md`.

## Setup

- GitHub MCP server: remote server `https://api.githubcopilot.com/mcp/`, configured in `.mcp.json` (listed in `.gitignore`).
- Token: a fine-grained GitHub personal access token with read-only access, passed through the `GITHUB_PERSONAL_ACCESS_TOKEN` environment variable and referenced in `.mcp.json` as `${GITHUB_PERSONAL_ACCESS_TOKEN}`. The token is stored in the macOS Keychain and never written to a file in the repository.
- Command: `claude -p ... --mcp-config .mcp.json --strict-mcp-config`, with read tools allowed (`pull_request_read`, `get_file_contents`).

## Connection check

Prompt: "List the names of all tools available from the github MCP server, one per line, nothing else."

Required tools reported by the agent:

```
add_comment_to_pending_review
add_issue_comment
add_reply_to_pull_request_comment
create_branch
create_or_update_file
create_pull_request
create_repository
delete_file
delete_repository
fork_repository
get_commit
get_file_contents
get_label
get_latest_release
get_me
get_release_by_tag
get_tag
get_team_members
get_teams
issue_read
issue_write
list_branches
list_commits
list_issue_fields
list_issue_types
list_issues
list_pull_requests
list_releases
list_repository_collaborators
list_tags
merge_pull_request
pull_request_read
pull_request_review_write
push_files
request_copilot_review
run_secret_scanning
search_code
search_commits
search_issues
search_pull_requests
search_repositories
search_users
sub_issue_write
update_issue_comment
update_pull_request
update_pull_request_branch
```

## Turn 1 — user

Review PR #1 from https://github.com/nebius-academy-templates/mobile-pr-review-practice

### Tool calls

- `mcp__github__pull_request_read` `{"method": "get", "owner": "nebius-academy-templates", "repo": "mobile-pr-review-practice", "pullNumber": 1}`
- `mcp__github__pull_request_read` `{"method": "get_diff", "owner": "nebius-academy-templates", "repo": "mobile-pr-review-practice", "pullNumber": 1}`
- `mcp__github__get_file_contents` `{"owner": "nebius-academy-templates", "repo": "mobile-pr-review-practice", "path": "/", "ref": "refs/heads/pr-01-ride-history", "fields": ["name", "type", "path"]}`
- `mcp__github__get_file_contents` `{"owner": "nebius-academy-templates", "repo": "mobile-pr-review-practice", "path": "src", "ref": "refs/heads/pr-01-ride-history", "fields": ["name", "type", "path"]}`
- `mcp__github__get_file_contents` `{"owner": "nebius-academy-templates", "repo": "mobile-pr-review-practice", "path": "README.md", "ref": "refs/heads/pr-01-ride-history"}`
- `mcp__github__get_file_contents` `{"owner": "nebius-academy-templates", "repo": "mobile-pr-review-practice", "path": "docs", "ref": "refs/heads/pr-01-ride-history", "fields": ["name", "type", "path"]}`
- `mcp__github__get_file_contents` `{"owner": "nebius-academy-templates", "repo": "mobile-pr-review-practice", "path": "docs/adr", "ref": "refs/heads/pr-01-ride-history", "fields": ["name", "path"]}`
- `mcp__github__get_file_contents` `{"owner": "nebius-academy-templates", "repo": "mobile-pr-review-practice", "path": "docs/adr/ADR-003-repository-pattern.md", "ref": "refs/heads/pr-01-ride-history"}`
- `mcp__github__get_file_contents` `{"owner": "nebius-academy-templates", "repo": "mobile-pr-review-practice", "path": "docs/adr/ADR-001-mvvm.md", "ref": "refs/heads/pr-01-ride-history"}`
- `mcp__github__get_file_contents` `{"owner": "nebius-academy-templates", "repo": "mobile-pr-review-practice", "path": "src/LoginViewModel.swift", "ref": "refs/heads/pr-01-ride-history"}`

## Turn 1 — agent

I've drafted the review of PR #1 below. Nothing has been posted to GitHub.

---

# Review draft: PR #1 "Add ride history screen"

This PR is in `mobile-pr-review-practice`, not GeoStampCamera, so the GeoStampCamera checks (stamps, `CameraService`, `project.yml`) don't apply. I checked it against the general mobile criteria and the repo's own architecture decision records (ADR-001 MVVM, ADR-003 repository pattern). It follows both: logic lives in a ViewModel, and data comes only through `RideRepository`.

## Findings

### src/RideHistoryViewModel.swift

- **[MAJOR]** line 17 — `try?` silently discards every error from `recentRides()`. A network failure, decoding error or server error shows the same empty list as an account with no rides, so the user gets no error message and no way to retry. Task cancellation also lands here: if the view disappears or `.refreshable` restarts the load, `CancellationError` replaces any rides already loaded with `[]`. — Use `do/catch` like `LoginViewModel.logIn` does: add `@Published var errorMessage: String?`, set it in `catch`, leave `rides` alone on failure, and ignore `CancellationError`.
- **[MINOR]** lines 14–16 — `loadRides()` isn't protected against running twice at once, for example `.task` plus pull-to-refresh. The first call's `defer` sets `isLoading = false` while the second call is still loading, so the spinner disappears too early, and whichever call finishes last decides the contents of `rides`. — Add `guard !isLoading else { return }` at the top, or keep the current `Task` and cancel it before starting a new one.
- **[MINOR]** line 14 — The new loading logic has no tests. This matters most for the error path and the empty-list path, which right now look the same. — Add unit tests with a stub `RideRepository` covering success, failure and empty results.

## Questions for the author

1. The description says the PR "adds a SwiftUI ride history screen", but the diff only adds the ViewModel. Is the view coming in another PR, or was it left out by mistake?
2. `Ride` and `RideRepository` aren't defined anywhere on this branch; `src/` only has the two login ViewModels and this file. Are they in another module or an earlier PR? If not, this file won't compile.
3. Should "failed to load" and "no rides yet" look different in the UI? The answer decides how the MAJOR finding should be fixed.

## Verdict

Request changes

## Summary

The PR adds `RideHistoryViewModel`, a main-actor `ObservableObject` that loads recent rides from `RideRepository` with async/await, following the repo's MVVM and repository-pattern rules. The main problem is that load failures are swallowed and look like an empty history. Findings: 0 BLOCKER, 1 MAJOR, 2 MINOR.

---

Should I post this review to the PR as a comment? It would go up as a plain comment, without an Approve or Request changes status. Reply **"yes"** or **"post"** to publish it; any other reply and I won't post.

## Turn 2 — user

no

### Tool calls

- none

## Turn 2 — agent

Okay, I won't post it. The review stays a local draft and nothing was sent to GitHub. If you want it changed, such as different severities or a shorter version, tell me what to adjust.

## Verification

- Session ID: `9c3fe84a-5615-4ca1-9fc8-bffaa96cabce`; permission denials in both turns: none.
- The agent fetched the PR with `pull_request_read` (methods `get` and `get_diff`) and read context files with `get_file_contents`.
- Output has a per-file section under Findings, Questions for the author, Verdict, and a closing Summary.
- The agent asked for confirmation before posting and accepted only "yes" or "post".
- After "no", the agent made no tool calls. Checked afterwards through the GitHub API: PR #1 has 0 comments and 0 reviews.
- Note: PR-01 is described as a clean PR, but the agent reported 1 MAJOR and 2 MINOR findings (swallowed errors via `try?`, concurrent loads, missing tests).
