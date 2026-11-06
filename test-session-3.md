# PR Review Agent — test session 3 (skills)

Captured on 2026-11-07 with Claude Code in the repository root, so the agent loads `CLAUDE.md` and the project skills in `.claude/skills/`.

## Setup

Project skills under test:

| Skill | Trigger in description | Invocation |
|---|---|---|
| `swift-conventions` | `.swift` files | model-invoked |
| `kotlin-conventions` | `.kt` / `.kts` files | model-invoked |
| `review-pr` | `/review-pr` only | user-invoked (`disable-model-invocation: true`) |

Target repository: https://github.com/nebius-academy-templates/mobile-pr-review-practice. PRs were read with the GitHub MCP tool `pull_request_read` (`get`, `get_diff`).

## Test 5a — Selective loading: Swift PR #2

Prompt:

> Review the Swift files in PR #2 https://github.com/nebius-academy-templates/mobile-pr-review-practice for style issues.

Tool calls, in order:

1. `Skill(swift-conventions)` → `Launching skill: swift-conventions`
2. `pull_request_read(method: get, pullNumber: 2)` → "Add profile screen", 1 changed file
3. `pull_request_read(method: get_diff, pullNumber: 2)` → `src/ProfileViewModel.swift` (new file, +14)

Result: **`swift-conventions` loaded, `kotlin-conventions` did not load.** ✅

Review draft produced by the agent:

```markdown
## Findings

### src/ProfileViewModel.swift

- [BLOCKER] lines 9–12 — `completion` runs on URLSession's background queue. The class is not `@MainActor` either, so any caller that updates the UI or `loading` from this callback does it off the main thread. — Mark the class `@MainActor` and change the method to `func fetchProfile(id: String) async throws -> Profile` using `try await URLSession.shared.data(from:)`.
- [MAJOR] line 9 — `FetchProfile` is UpperCamelCase, but Swift function names must be lowerCamelCase. — Rename it to `fetchProfile(id:)`.
- [MAJOR] line 10 — The response and error are thrown away (`data, _, _`). A network failure, an HTTP 4xx/5xx, or a bad body all return `nil`, so the caller can't tell "not found" from "request failed". — Make the method `throws`, check that the HTTP status is 2xx, and pass errors on to the caller.
- [MAJOR] line 1 — The view model imports `UIKit` but never uses it, and the comment on line 3 says the screen is UIKit rather than SwiftUI. That mixes UI frameworks against the project's chosen one. — Import `Foundation` in the view model and build the screen in the project's main framework.
- [MINOR] line 6 — The Boolean `loading` has no `is`/`has` prefix, and nothing in the diff ever sets it. — Rename it to `isLoading`, and set it at the start and end of the fetch (or remove it).
- [MINOR] line 14 — The file doesn't end with a newline. — Add one.

## Questions for the author

- The description says this PR "adds the user profile screen", but the diff only has the view model. Is the view in another PR?
- `Profile`, `Profile.init(_: Data)` and `profileURL(_:)` aren't defined in this diff. Do they already exist on `main`, and does `Profile.init` return `nil` on bad data instead of crashing?
- Are there tests planned for `fetchProfile` (success, HTTP error, bad data)?

## Verdict

Request changes

## Summary

This PR adds `ProfileViewModel` with a fetch method that uses callbacks and URLSession. The main problems are that the callback runs off the main thread, network errors are ignored, and the naming and framework choice break the Swift conventions. Findings: 1 BLOCKER, 3 MAJOR, 2 MINOR.
```

The agent then asked: "Should I post it on PR #2 as a comment-only review, with no approve or request-changes status? Reply **yes** or **post** to post it. Any other reply means I won't."

The user's next message was neither "yes" nor "post". The agent said "This paste isn't 'yes' or 'post', so I won't post the PR #2 review." **Nothing was posted.** ✅

## Test 5b — Selective loading: Kotlin PR #4

Prompt:

> Review the Kotlin files in PR #4 from https://github.com/nebius-academy-templates/mobile-pr-review-practice for style issues.

Tool calls, in order:

1. `Skill(kotlin-conventions)` → `Launching skill: kotlin-conventions`
2. `pull_request_read(method: get, pullNumber: 4)` → "Add trip list screen", 1 changed file
3. `pull_request_read(method: get_diff, pullNumber: 4)` → `src/TripViewModel.kt` (new file, +22)

(The first attempt at steps 2–3 got no verdict from the auto-mode classifier because it was batched with other calls. Each call was reissued on its own and succeeded.)

Result: **`kotlin-conventions` loaded, `swift-conventions` did not load again.** ✅

Review draft produced by the agent:

```markdown
## Findings

### src/TripViewModel.kt

- [BLOCKER] line 19 — `"/users/{userId}/trips"` isn't a Kotlin string template, so the request goes to the literal path `/users/{userId}/trips`. The `userId` parameter is never used and no rider's trips will load. — Use `"/users/$userId/trips"` and URL-encode `userId` if it can contain any character.
- [MAJOR] lines 17–19 — `apiClient.get` runs inside `viewModelScope.launch` with no `try/catch`. A network or parsing error is an uncaught exception, which crashes the app. — Wrap the call in `try/catch`, rethrow `CancellationException`, and put an error state in the UI state.
- [MAJOR] lines 10, 18–19 — The ViewModel calls `ApiClient` directly and builds endpoint paths itself instead of going through a data layer, which is the pattern in the skill's compliant example. — Add a `TripRepository` with `suspend fun getTrips(userId: String): List<Trip>` and inject that instead.
- [MINOR] line 14 — `val trips: StateFlow<List<Trip>> = _trips` only upcasts, so a caller can cast it back to `MutableStateFlow` and change it. — Use `_trips.asStateFlow()`.
- [MINOR] line 22 — The file doesn't end with a newline. — Add one.

## Questions for the author

- Is `ApiClient.get` a main-safe `suspend` function that switches to `Dispatchers.IO` itself? If it blocks, it is blocking the main thread here (Coroutines rule, CRITICAL).
- The description says this PR adds the trip list screen, but the diff only has the ViewModel. Is the screen in another PR?
- Are there tests for `loadTrips` (success, error, empty list)?

## Verdict

Request changes

## Summary

This PR adds `TripViewModel`, which loads a rider's trips into a `StateFlow`. The endpoint path never inserts `userId`, so the screen can't load the right trips. API errors crash the app, and the API client is called without a repository. Findings: 1 BLOCKER, 2 MAJOR, 2 MINOR.
```

The agent then asked: "Should I post it on PR #4 as a comment-only review? Reply **yes** or **post** to post it. Any other reply means I won't."

The user's next message was "add test-session 3", which is not "yes" or "post". **Nothing was posted.** ✅

## Selective loading summary

| PR | Changed file | swift-conventions | kotlin-conventions | Expected |
|---|---|---|---|---|
| #2 | `src/ProfileViewModel.swift` | loaded | not loaded | ✅ |
| #4 | `src/TripViewModel.kt` | not loaded | loaded | ✅ |

No description changes were needed.

## Test 6 — Workflow skill `/review-pr 1`

`review-pr` sets `disable-model-invocation: true`, so the model cannot start it. The user has to type it:

```
/review-pr https://github.com/nebius-academy-templates/mobile-pr-review-practice/pull/1
```

Expected:
- The agent works through Steps 1–7 in order.
- At Step 7 it stops and asks: "Post this review to the PR as a comment? Reply **yes** or **post** to post it. Any other reply means it will not be posted."
- When the user answers **no**, it replies "Review not posted." and calls no GitHub write tools.

_Status: not run yet in this session. Add the output of this run below once you have it._

## Skill file check (step 8)

| File | Trigger extension in description | Rules | Template | Status |
|---|---|---|---|---|
| `.claude/skills/swift-conventions/SKILL.md` | `.swift` | 3 | compliant + non-compliant snippet | ✅ (description could be more specific) |
| `.claude/skills/kotlin-conventions/SKILL.md` | `.kt` (and `.kts`) | 3 | compliant + non-compliant snippet | ✅ |
| `.claude/skills/review-pr/SKILL.md` | — (user-invoked) | Steps 1–8, in order, with a hard stop at Step 7 | review output template | ✅ |
