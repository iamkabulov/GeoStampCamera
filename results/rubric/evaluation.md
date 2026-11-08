# Evaluation

## Rubric

Expectations for running `/review-pr` on the five PRs in `nebius-academy-templates/mobile-pr-review-practice`. Line numbers are new-file lines from each PR's diff. Severities follow the review-pr mapping: a skill rule marked CRITICAL becomes BLOCKER, and MAJOR stays MAJOR.

| Input | Expected finding | Expected severity | Expected reference |
|---|---|---|---|
| PR-01 — clean PR | No convention, security, or architecture violations. The ViewModel is `@MainActor`, the repository is injected, and the work uses async/await. At most an optional note that `try?` (line 17) hides load errors behind an empty list. | None (an optional MINOR or a question for the author is acceptable). Verdict: **Approve** or **Approve with comments**. | `src/RideHistoryViewModel.swift` — no rule cited. Any BLOCKER or MAJOR counts as a false positive. |
| PR-02 — Swift naming violations | 1. `FetchProfile` is UpperCamelCase; functions must be lowerCamelCase.<br>2. Boolean `loading` is missing an `is`/`has`/`can` prefix.<br>3. A new screen uses UIKit instead of the project's SwiftUI.<br>4. The `dataTask` completion runs on a background queue with no main-thread hop, and it uses a completion handler instead of async/await. | 1. MAJOR<br>2. MAJOR<br>3. MAJOR<br>4. BLOCKER<br>Verdict: **Request changes** | `src/ProfileViewModel.swift`<br>1. line 9 — swift-conventions §1 Naming<br>2. line 6 — §1 Naming<br>3. line 1 — §3 UIKit and SwiftUI Usage<br>4. lines 10–11 — §2 Concurrency and Thread Safety |
| PR-03 — hardcoded API key | 1. A live secret (`sk-live-…`) is hardcoded in a public property. Expected fix: revoke and rotate the key, and keep it off the client.<br>2. `API_KEY` is a class `val` named in SCREAMING_SNAKE_CASE. | 1. **BLOCKER**<br>2. MAJOR<br>Verdict: **Request changes** | `src/PaymentService.kt`<br>1. line 8 — security-reviewer (hardcoded credentials)<br>2. line 8 — kotlin-conventions §1 Naming<br>The secret value must not be repeated in the review. |
| PR-04 — bypasses repository layer | 1. The ViewModel calls `apiClient` directly instead of going through a repository.<br>2. Bonus: `"/users/{userId}/trips"` is not a Kotlin template (it should use `$userId`), so every request sends the literal `{userId}`. | 1. **MAJOR**<br>2. BLOCKER<br>Verdict: **Request changes** | `src/TripViewModel.kt`<br>1. lines 10 and 19 — **ADR-003 (Repository Pattern)**, cited by architecture-reviewer<br>2. line 19 — correctness |
| PR-05 — mixed issues | 1. Hardcoded live `CLIENT_SECRET` that is also sent in the request body.<br>2. `GlobalScope.launch` instead of `viewModelScope` leaks work past the ViewModel lifecycle.<br>3. Direct `apiClient` call from the ViewModel, plus the uninterpolated `{orderId}` path.<br>4. `CLIENT_SECRET` is a class `val` in SCREAMING_SNAKE_CASE.<br>5. `ApplyCoupon` is UpperCamelCase and uses a completion handler instead of async/await. | 1. **BLOCKER**<br>2. BLOCKER<br>3. MAJOR (path: BLOCKER)<br>4. MAJOR<br>5. MAJOR<br>Verdict: **Request changes** | `src/CheckoutViewModel.kt`<br>1. lines 11 and 16 — security-reviewer<br>2. line 15 — kotlin-conventions §2 Coroutines and Threading (§3 Jetpack and Lifecycle is also acceptable)<br>3. line 16 — ADR-003 (Repository Pattern)<br>4. line 11 — kotlin-conventions §1 Naming<br>`src/CouponView.swift`<br>5. line 7 — swift-conventions §1 Naming, §2 Concurrency<br>Both files must appear under Findings. |

## Scores

Scored against the saved drafts in `outputs/pr-0N-output.md`. "N/A" means the column does not apply to that PR (no ADR is expected). A row fails if any cell is ✗.

| Input | Correct findings? | Hallucinated rule? | Severity correct? | ADR cited (if applicable)? | Result |
|---|---|---|---|---|---|
| PR-01 | ✗ | ✓ | ✗ | N/A | **Fail** |
| PR-02 | ✗ | ✓ | ✗ | N/A | **Fail** |
| PR-03 | ✗ | ✓ | ✗ | N/A | **Fail** |
| PR-04 | ✓ | ✓ | ✓ | ✗ | **Fail** |
| PR-05 | ✗ | ✓ | ✗ | ✗ | **Fail** |

"Hallucinated rule?" ✓ means no invented rule was cited.

### Notes

- **PR-01:** The `try?` point (line 17) is the expected one, but it was reported as MAJOR and the verdict was **Request changes**. The rubric allows at most a MINOR and Approve / Approve with comments, so the MAJOR counts as a false positive.
- **PR-02:** All four issues are touched on, but `FetchProfile` (line 9) and `loading` (line 6) were rated MINOR instead of MAJOR, and the background-queue completion (lines 10–11) was rated MAJOR instead of BLOCKER. UIKit instead of SwiftUI was only a question for the author. The finding at line 1 says the import is unused, which doesn't flag the framework choice.
- **PR-03:** The secret BLOCKER on line 8 is correct, includes revoke and rotate, and doesn't repeat the value. The `API_KEY` naming problem (MAJOR) was folded into the BLOCKER's fix text instead of being its own finding.
- **PR-04:** Both expected findings and severities match: the repository bypass is MAJOR (lines 10, 19) and `{userId}` is a BLOCKER (line 19). ADR-003 was not cited. `docs/adr/ADR-003-repository-pattern.md` is empty (0 bytes), so architecture-reviewer's ADR search returned nothing.
- **PR-05:** The secret and the `{orderId}` path are BLOCKERs, which is correct, and both files appear. `GlobalScope` (line 15) was rated MAJOR instead of BLOCKER. The direct `apiClient` call (line 16) was rated MINOR instead of MAJOR. The `CLIENT_SECRET` naming finding (MAJOR) is missing, and `ApplyCoupon` naming (line 7) was rated MINOR instead of MAJOR. ADR-003 was not cited.

### Root causes

1. **Severity downgrades during compilation.** style-reviewer reported `FetchProfile`, `API_KEY`, `CLIENT_SECRET` and `ApplyCoupon` naming as MAJOR and `GlobalScope` as BLOCKER (CRITICAL rule), but the compile step lowered or dropped them. The review-pr skill does not state the rubric's mapping (CRITICAL → BLOCKER, MAJOR stays MAJOR), so add it to Step 3.
2. **Empty ADR files.** `ADR-001-mvvm-architecture.md` and `ADR-003-repository-pattern.md` are both 0 bytes, so no ADR could be cited. Fill them in and re-run PR-04 and PR-05.
3. **Overly strict on a clean PR.** On PR-01, a `try?` UX concern was rated MAJOR. The compile step should keep subagents' "no findings" results unless the issue is a demonstrable bug.

## Improvement proposal

### Which PR failed and how

**PR-05 (mixed issues)** fails on three of the four columns, which is the most of any row. The clearest single failure is the `GlobalScope.launch` problem on line 15. It breaks kotlin-conventions §2 Coroutines and Threading, which is marked **CRITICAL**, so the expected severity is **BLOCKER**. The final draft rated it **MAJOR**. In the same row, the `CLIENT_SECRET` naming finding (expected MAJOR) was missing, `ApplyCoupon` naming was rated MINOR instead of MAJOR, and the direct `apiClient` call was rated MINOR instead of MAJOR.

The same failure explains the severity ✗ on PR-02 and PR-03 as well:
- PR-02: the background-queue completion should be BLOCKER (swift-conventions §2 Concurrency is CRITICAL) but was rated MAJOR. `FetchProfile` and `loading` should be MAJOR but were rated MINOR.
- PR-03: the `API_KEY` naming finding (MAJOR) was folded into the BLOCKER's fix text instead of being its own finding.

### Root cause from the trace (failure mode)

The subagents rated these findings correctly. The orchestrator then changed their severity in Step 3, when it combined the three reports. The trace shows this directly:

| PR | Subagent span output | Final draft |
|---|---|---|
| PR-05 | style-reviewer: `[BLOCKER] 15 — GlobalScope.launch … (rule: Coroutines and Threading, CRITICAL)` | `[MAJOR] 15` |
| PR-05 | style-reviewer: `[MAJOR] 11 — val CLIENT_SECRET uses SCREAMING_SNAKE_CASE` | missing (merged into the secret BLOCKER) |
| PR-05 | style-reviewer: `[MAJOR] 7 — func ApplyCoupon starts with an uppercase letter` | `[MINOR] 7` |
| PR-02 | style-reviewer: `[MAJOR] 9 — FetchProfile … (rule: Naming Conventions)` | `[MINOR] 9` |
| PR-03 | style-reviewer: `[MAJOR] 8 — val API_KEY … SCREAMING_SNAKE_CASE` | missing (merged into the secret BLOCKER) |

**Failure mode: lossy aggregation.** The orchestrator re-scored subagent severities on its own judgment ("this is cosmetic, so it's MINOR") and merged findings that cite different rules on the same line. Step 3 of `.claude/skills/review-pr/SKILL.md` says only "Combine the subagent results … into one Markdown document". It doesn't say that severity comes from the rule's tag. It doesn't say that one finding must not absorb another from a different rule. And nowhere in the pipeline is the CRITICAL → BLOCKER mapping stated. `kotlin-conventions` states it on line 8, but `swift-conventions` and `review-pr` do not. Without a rule, the orchestrator filled the gap with its own opinion.

### The exact change and why

In `.claude/skills/review-pr/SKILL.md`, Step 3, add these bullets under `Rules:` (after line 58):

```markdown
- Severity is set by the rule, not by you. A finding that cites a conventions rule takes that rule's tag: CRITICAL → BLOCKER, MAJOR → MAJOR, MINOR → MINOR. Keep the severity a subagent assigned; you may only raise it, never lower it.
- Never merge findings that cite different rules, even on the same line. Emit one bullet per (line, rule) pair — e.g. a hardcoded secret (security) and its SCREAMING_SNAKE_CASE name (Naming) are two findings.
- A finding with no rule citation keeps the subagent's severity only if it describes a concrete runtime failure (crash, wrong request, data loss). Otherwise, cap it at MINOR or move it to Questions for the author.
```

Why each bullet:
1. **Severity from the rule.** This gives every finding an objective severity that matches the rubric. It removes the step where severities drifted, and the "raise only" clause still lets the orchestrator escalate a real security issue.
2. **One bullet per (line, rule).** This brings back the missing `API_KEY` and `CLIENT_SECRET` naming findings on PR-03 and PR-05.
3. **Cap findings with no rule citation.** This stops a judgment call on code that has no bug from becoming a MAJOR, as happened with `try?` on PR-01. A PR-01 run under this rule would land at MINOR / Approve with comments, which matches the rubric.

### Why this is the highest-priority fix

- **Broadest impact.** One missing rule in a single file causes the severity ✗ on 4 of 5 rows (PR-01, PR-02, PR-03, PR-05) and the findings ✗ on PR-02, PR-03 and PR-05. No other cause touches more than two rows.
- **Most dangerous direction.** The failures run toward *under*-reporting: a CRITICAL threading bug shown as MAJOR, findings silently dropped. A human reviewer who triages by severity would miss them. Over-reporting costs time, but under-reporting lets bugs reach production.
- **Cheap and safe.** It is a three-bullet text change to one skill file. It touches no subagents, tools or posting guardrails, and it can be checked by re-running the same five PRs.
- **Why not the alternatives.** Filling in the empty ADR files (`docs/adr/ADR-003-repository-pattern.md` is 0 bytes) fixes only the ADR column on PR-04 and PR-05, and it is a content gap rather than an agent-behaviour failure. It's worth doing next, because it would turn PR-04 into a full pass.
