# PR Review Agent — test session 4 (reviewer subagents)

Captured on 2026-11-08 with Claude Code (model: Claude Opus 5.5), started in the repository root so the agent loads `CLAUDE.md`.

## Setup

- Skill: `.claude/skills/review-pr/SKILL.md`. In this version, Step 2 runs three reviewer subagents in parallel.
- Subagents in `.claude/agents/`. All three are read-only (`tools: Read, Grep, Glob`):
  - `style-reviewer` (haiku, preloads the `swift-conventions` and `kotlin-conventions` skills)
  - `security-reviewer` (sonnet)
  - `architecture-reviewer` (sonnet, preloads the `swift-mvvm` skill)
- GitHub access: GitHub MCP server, read tool `pull_request_read`.

## Earlier attempt in the same session: `/review-pr 3`

When only `3` was given, the agent took the repo from this checkout's `origin` remote (`iamkabulov/GeoStampCamera`). All three `pull_request_read` calls (`get`, `get_diff`, `get_files`) returned `404 Not Found`. The agent reported the error and stopped, as Step 1.2 requires. The subagent definitions were then fixed (see the "Fixes made before this run" section), and `/review-pr` was run again with no argument. The agent asked for the PR URL or `owner/repo#number` and stopped.

## Invocation

```
/review-pr 3 https://github.com/nebius-academy-templates/mobile-pr-review-practice/pull/3
```

## Step 1 — Fetch the PR

Three calls: `pull_request_read` with `method` set to `get`, `get_diff`, and `get_files`, for `owner=nebius-academy-templates`, `repo=mobile-pr-review-practice`, `pullNumber=3`.

- Title: "Add payment service"
- Description: "Adds the payment service that charges a rider's saved card via the payments API."
- State: open, 1 commit, 1 changed file, +18 lines
- Changed files, in diff order: `src/PaymentService.kt` (added)

Diff:

```diff
diff --git a/src/PaymentService.kt b/src/PaymentService.kt
new file mode 100644
--- /dev/null
+++ b/src/PaymentService.kt
@@ -0,0 +1,18 @@
+package com.rideapp.payments
+
+import retrofit2.Retrofit
+import retrofit2.converter.gson.GsonConverterFactory
+
+class PaymentService {
+
+    val API_KEY = "sk-live-9f8a7b6c5d4e3f2a1b0c9d8e7f6a5b4c"
+
+    private val retrofit = Retrofit.Builder()
+        .baseUrl("https://api.rideapp.com/payments/")
+        .addConverterFactory(GsonConverterFactory.create())
+        .build()
+
+    fun charge(amount: Int, token: String) {
+        // Sends the charge request with API_KEY in the Authorization header.
+    }
+}
\ No newline at end of file
```

## Step 2 — Reviewer subagents

All three were launched in one message and ran in parallel. Each prompt contained the full diff with line numbers, the ordered list of changed files, and the PR title and description. Each prompt also said that the PR is in a Kotlin/Android repo, not GeoStampCamera, so the reviewer should work from the diff only. The security prompt said to skip the `project.yml`/`INFOPLIST_KEY_*` check. The architecture prompt said to skip the GeoStampCamera-specific checks and apply only the language-agnostic principles from `swift-mvvm`.

| Subagent | Tokens | Tool uses | Duration |
|---|---|---|---|
| security-reviewer | 9,703 | 1 | 8.4 s |
| style-reviewer | 13,087 | 1 | 11.1 s |
| architecture-reviewer | 14,367 | 1 | 13.4 s |

### security-reviewer report

```
### src/PaymentService.kt
- [BLOCKER] 8 — Security: Hardcoded live API key (`sk-live-...`) is committed in source. Anyone with repo access or the decompiled APK can extract it and make live charges. The field is also public (`val API_KEY` with no `private`), so any other class can read it. — Revoke and rotate this key now, because it is in git history and must be treated as compromised. Do not ship a secret in the client at all. Have the app call your own backend, which holds the key and calls the payments API. If a client credential is unavoidable, use a short-lived per-session token fetched after the user authenticates. Never store it in source or BuildConfig.
- [MAJOR] 15 — Security: `charge(amount: Int, token: String)` has no input validation. It accepts a zero or negative `amount` and a blank `token`. It is also unclear whether `amount` comes from the client, and a client-supplied amount can be tampered with. The body is a stub, so this is a risk once it is implemented. — Validate `amount > 0` and a non-blank, well-formed `token`. Compute the amount server-side. Send an idempotency key so retries do not double-charge.
- [MAJOR] 10 — Security: The Retrofit client has no OkHttp client configured. Nothing controls logging, so if someone later adds `HttpLoggingInterceptor` at BODY level, the Authorization header and card/token data could leak to logcat in release builds. There is also no certificate pinning for a payments endpoint. HTTPS is used, which is fine. — Build an explicit `OkHttpClient`. Keep logging off in release builds, or redact the Authorization header. Consider certificate pinning via `CertificatePinner`.

### Questions
- Is the `token` parameter a payment-method token or a raw card number? The description says it charges a "saved card". If raw card data passes through here, that is a PCI-scope concern.
- Where does the saved card come from, and where is it stored? That code is not in this diff, so I could not check it.
- The comment on line 16 says the key goes in the Authorization header, but nothing implements it. The PR is incomplete, so the points above apply to the final implementation.
```

### style-reviewer report

```
### src/PaymentService.kt
- [MAJOR] 8 — `API_KEY` is a class-member `val` written in SCREAMING_SNAKE_CASE. The naming rule requires lowerCamelCase for properties, and SCREAMING_SNAKE_CASE applies only to `const val` and top-level or object immutable constants. (rule: Naming Conventions) — Rename to `apiKey`. If it is meant as a compile-time constant, declare it as `private const val API_KEY` in a companion object or at top level.

Notes:
- kotlin-conventions skill was found and applied to all changed lines. The swift-conventions skill was not applied because the diff has no Swift files.
- Out of scope for the style rules: line 8 hardcodes what looks like a live API key (`sk-live-...`) in source. No style rule covers this, so it is flagged here only for the security reviewer and the author.
- `charge()` (lines 15-17) is an empty, non-suspend function with no I/O. The Coroutines and Threading rules have nothing to evaluate yet. Re-check them when the request is implemented, since a suspend network call will need `withContext(Dispatchers.IO)` or an injected dispatcher.
```

### architecture-reviewer report

```
### src/PaymentService.kt
- [BLOCKER] 8 — A live API secret (`sk-live-...`) is hardcoded in source and exposed as a public `val`. It ends up in git history and in the APK, where it is trivially extractable. Anyone with repo or APK access can charge against the payments API. The `val` is public, so any caller can also read it. — Revoke and rotate the key now. Do not ship a secret in the client. Have the payments API authenticate the rider with their session token, or route charges through your backend, which holds the key. If a client-side credential is unavoidable, inject it at build time (not committed) and keep it `private`.
- [MAJOR] 10-13 — `Retrofit` is built inline inside the service, so the dependency is hidden. The base URL, converter and HTTP client cannot be swapped, and the service cannot be unit-tested with a fake or `MockWebServer`. There is also no `OkHttpClient` configuration (timeouts, auth interceptor, logging policy). — Inject a `PaymentsApi` Retrofit interface (or a `PaymentGateway` interface) through the constructor and build Retrofit in a composition root or DI module. Add an `Authorization` interceptor there.
- [MAJOR] 15-17 — `charge` has an empty body, so it does nothing. The comment says it sends the request, but no request is made. Callers will treat a charge as successful when no money moved. The return type is `Unit`, so success and failure cannot be reported. It is also a non-suspend, non-async signature for network work, so a real implementation would block the calling thread and crash with `NetworkOnMainThreadException` if called from the main thread. — Define a `PaymentsApi` with `@POST suspend fun charge(...)`. Make `charge` a `suspend` function that returns a `Result<ChargeReceipt>` or a sealed type. Run it on `Dispatchers.IO` (injected as a dispatcher for testability). Map errors to domain errors for the UI layer.
- [MAJOR] 15 — `amount: Int` has no currency or unit (minor units vs. major units), and `token: String` is an unvalidated card token. The charge is not idempotent, so a retry or double-tap could charge the rider twice. This is the part of the PR that matters most for money movement. — Use a typed `Money(amountMinor: Long, currency)`. Send an idempotency key with each charge request and validate inputs.
- [MINOR] 3-4 — Retrofit and Gson are new third-party dependencies, and the diff shows no build file change. The build will fail unless they are already declared. Gson is also weak for Kotlin because it ignores nullability and defaults. — Confirm the dependencies are declared. Consider kotlinx.serialization or Moshi.
- [MINOR] 1 and file path — The package is `com.rideapp.payments`, but the file sits at `src/PaymentService.kt` and not in a matching package directory. The file has no trailing newline. — Move it to `src/.../com/rideapp/payments/` and add a final newline.
- [MINOR] 6 — The concrete class has no interface. Callers (such as a ViewModel) cannot substitute a fake in tests. — Introduce `interface PaymentService` with a `RetrofitPaymentService` implementation, bound through DI.

## Questions
- Is `sk-live-...` a real production key? If so, treat it as leaked and rotate it. It is already in the PR branch history, so removing it from the file is not enough.
- The PR description says it charges a "saved card". Where are saved-card tokens obtained and stored? This diff has no such flow.
- Are there tests or a DI setup (Hilt, Koin) elsewhere in the repo that this class should follow? I reviewed the diff only.
```

## Step 3 — Compilation decisions

How the main agent combined the three reports:

- Merged the line-8 BLOCKERs from security and architecture into one finding.
- Merged the line-15 input validation, units and idempotency findings into one MAJOR.
- Kept the style reviewer's naming finding at MAJOR, as the skill's mapping requires. Its fix points back to the BLOCKER.
- Dropped the security MAJOR on line 10 about a logging leak, because it depended on code someone might add later ("if someone later adds…"). That finding's point about the missing `OkHttpClient` was folded into the DI finding.
- Downgraded the Retrofit-inline/DI finding from MAJOR to MINOR (merged with the line-6 interface finding). The architecture reviewer's own severity rules put "DI improvements that would not break anything today" at MINOR.
- Moved "dependencies not declared in build files" from Findings to Questions, because the build files can't be checked from the diff. Dropped "consider Moshi/kotlinx.serialization" as generic advice.
- Removed the author's name from the output.

## Steps 4–5 — Review draft presented to the user

```markdown
## Findings

### src/PaymentService.kt
- [BLOCKER] 8 — A live payments secret (`sk-live-…`) is hardcoded in source, and the property is public, so any class can read it. The key is now in git history and will be compiled into the APK, where anyone can pull it out and make live charges. — Revoke and rotate the key now; deleting the line won't remove it from history. Keep the secret off the client: send charges through a backend that holds the key, or use a short-lived token issued to each signed-in user.
- [MAJOR] 15–17 — `charge` has an empty body and returns `Unit`. The comment says it sends a request, but nothing is sent and the caller gets no way to see success or failure, so a caller will assume the charge worked when no money moved. The function is also not `suspend`, so once a real network call goes in, calling it from the main thread will block the thread or crash with `NetworkOnMainThreadException`. — Implement it through a Retrofit interface with `@POST suspend fun charge(...)`. Make `charge` a `suspend` function that returns `Result<ChargeReceipt>` or a sealed result type, and run it on an injected IO dispatcher.
- [MAJOR] 15 — The signature `charge(amount: Int, token: String)` says nothing about currency or units (cents vs. whole units) and accepts zero, negative and blank values. Nothing stops a retry or a double tap from charging the rider twice. — Use a typed `Money(amountMinor: Long, currency)`, check that `amount > 0` and the token isn't blank, and send an idempotency key with every charge request.
- [MAJOR] 8 — `API_KEY` is an ordinary class property named in SCREAMING_SNAKE_CASE. The kotlin-conventions naming rule reserves that style for `const val` and top-level or object constants. — This goes away once the key is removed (see the BLOCKER). Any constant that stays should be a `private const val` in a companion object; any other property should be lowerCamelCase.
- [MINOR] 6, 10–13 — Retrofit is built inside the concrete class, so the base URL, the HTTP client and the converter can't be replaced, and callers can't swap in a fake for tests. No `OkHttpClient` is set up either, so there are no timeouts, no auth interceptor and no logging policy. — Add an `interface PaymentService` with a Retrofit-backed implementation. Inject a `PaymentsApi` through the constructor, and build Retrofit and the `OkHttpClient` (with the auth interceptor) in one shared setup module.
- [MINOR] 1 — The package is declared as `com.rideapp.payments`, but the file is at `src/PaymentService.kt`, and it has no trailing newline. — Move the file to the matching `.../com/rideapp/payments/` directory and add a final newline.

## Questions for the author
- Is `sk-live-9f8a…` a real production key? If so, treat it as leaked even after this PR changes.
- Is `token` a payment-method token from the card processor, or raw card data? The description says it charges a "saved card"; if raw card numbers pass through here, the app falls under PCI compliance rules.
- Where are saved-card tokens obtained and stored? That flow isn't in this diff.
- Are Retrofit and the Gson converter already declared in the build files? This diff doesn't change any build file.
- Does the repo already use a DI setup (Hilt or Koin) and a testing pattern that this class should follow?

_Not covered: this review is based on the diff only, because the repository's other code (build files, DI setup, callers) wasn't available. The GeoStampCamera-specific checks don't apply to this Kotlin repo and were skipped._

## Verdict
Request changes

## Summary
This PR adds `PaymentService`, a Retrofit-based class that is meant to charge a rider's saved card, but `charge` is still empty and the class hardcodes a live API key. Findings: 1 BLOCKER, 3 MAJOR, 2 MINOR.
```

Confirmation prompt shown right after the draft:

> Post this review to the PR as a comment? Reply **yes** or **post** to post it. Any other reply means it will not be posted.

## Step 6 — User reply

The user replied: "Copy the full conversation from the '/review-pr' 3 run, or have your tool capture it. Save it as test-session-4.md"

That reply is not `yes` or `post`, so the agent did not post. No GitHub write tool (`pull_request_review_write`, `add_comment_to_pending_review`) was called during the session. **Review not posted.**

## Observations

- The human-in-the-loop guardrail held. The agent stopped after the draft, and a reply other than yes/post did not trigger posting.
- The three subagents ran in parallel and each returned the per-file format it was asked for, so their reports were easy to merge.
- The security and architecture reviewers overlapped on the hardcoded key, and the main agent removed the duplicate. The main agent also filtered out one speculative finding and adjusted two severities. Without that step, the raw subagent output would have overstated the review.
- The subagents' `description` fields still mention old step numbers ("step 2/4/5"); all three now run in Step 2. This doesn't change behavior, but the descriptions should be updated.
- The `architecture-reviewer` prompt and the `security-reviewer` `INFOPLIST_KEY_*` check are written for GeoStampCamera. For a PR in another repo, the main agent had to tell each subagent which checks to skip.
