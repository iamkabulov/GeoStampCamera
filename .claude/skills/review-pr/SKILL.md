---
name: review-pr
description: Run the full PR review workflow end to end — fetch the PR, check Swift and Kotlin conventions, flag security issues, draft the review, and post it only after explicit approval. Use only when the user explicitly invokes /review-pr or explicitly asks to "run the review-pr workflow" on a PR; do not trigger automatically.
disable-model-invocation: true
argument-hint: <PR URL | owner/repo#number>
---

# review-pr

Follow these steps exactly as written, in order. Do not skip, reorder, merge, or add steps. Do not take any action that is not listed here. You are read-only until Step 6: never modify files, commit, push, approve, merge, or comment on a PR before then.

Input: `$ARGUMENTS` — the PR to review. If it is empty, ask the user for the PR URL or `owner/repo#number` and stop until they answer.

## Step 1 — Fetch the PR

1. Use the GitHub MCP server's `pull_request_read` tool to get the PR details, the diff, and the list of changed files. Do not use `gh`, `git`, `curl`, or any other shell command to access GitHub.
2. If the fetch fails, report the error and stop.
3. If the diff is empty, report exactly "No changes to review" and stop.
4. Record the changed files in the order they appear in the diff. Every one of them must appear in the final output.

## Step 2 — Run the reviewer subagents

Launch these three subagents in parallel (one message, three Agent calls). Give each one the full diff from Step 1 and the ordered list of changed files. The subagents have no GitHub access, so the diff in the prompt is all they see.

1. `style-reviewer`: checks Swift and Kotlin files against the conventions skills.
2. `security-reviewer`: checks every file for security and privacy issues.
3. `architecture-reviewer`: checks the diff against the project architecture.

Wait for all three to finish. If one fails, keep going and add a note that its area was not covered.

## Step 3 — Compile findings into the output format

Combine the subagent results from Step 2 with the project review criteria from `CLAUDE.md` (PR Review Agent section) into one Markdown document with these H2 sections, in this order:

```
## Findings
### <file path>            ← one per changed file, in diff order
- [BLOCKER] <line> — <problem> — <suggested fix>
- [MAJOR] ...
- [MINOR] ...
(or "No findings." — never omit a changed file)

## Questions for the author   ← omit if empty
- <uncertain point>

## Verdict
<exactly one of: Approve | Approve with comments | Request changes>

## Summary
<two or three sentences on what the PR changes, plus the count of findings per severity>
```

Rules:
- Only report issues traceable to a specific file and line in the diff. Never invent problems.
- If unsure whether something is a bug, put it under Questions for the author, not Findings.
- Within each file, list findings most severe first.
- Do not include author names or internal ticket IDs.
- Do at most 2 review passes. If something could not be covered, add a note saying what was not covered.

## Step 4 — Present the review

Show the complete review draft from Step 3 to the user.

## Step 5 — Ask for confirmation before posting

Immediately after the draft, ask exactly:

> Post this review to the PR as a comment? Reply **yes** or **post** to post it. Any other reply means it will not be posted.

Then stop and wait for the user's reply. Do not call any GitHub write tool before the user replies.

## Step 6 — Post only on "yes" or "post"

- If the reply is exactly `yes` or `post` (case-insensitive, ignoring surrounding whitespace and punctuation): post the review using the GitHub MCP write tools (`pull_request_review_write` / `add_comment_to_pending_review`) as a **COMMENT** only — never with the APPROVE or REQUEST_CHANGES event. Then report the link to the posted review.
- Any other reply — including "no", a question, an edit request, or no reply — means do not post. Say "Review not posted." If the user asked for changes, revise the draft, then go back to Step 3.

Never approve, merge, close, or push to the PR under any circumstances.
