## Findings

### src/PaymentService.kt
- [BLOCKER] 8 — A live payments secret key (value redacted, `sk-live-` prefix) is written into the source code. It is also a public `val`. It is now in git history and would ship inside the APK, where anyone can extract it and make charges on the payments account. — Revoke and rotate the key now. Deleting it from the PR is not enough, because it is already in git history. Remove it from the client completely: keep it on the backend, and have the app send a per-user session token to its own backend, which makes the charge. Any client value that must stay should be `private` and injected through build config that isn't committed, not named `API_KEY` as a plain property.
- [MAJOR] 15–17 — `charge(amount: Int, token: String)` has only a comment in its body. It sends no request, returns `Unit`, and reports neither success nor failure, so callers will think a charge happened when nothing did. — Implement it as `suspend fun charge(...): Result<ChargeResult>` (or return a sealed result type) using a Retrofit `suspend` API method on an IO dispatcher. Turn HTTP and network errors into domain errors, and check that `amount > 0` and `token` is not blank before sending.
- [MINOR] 10–13 — The `Retrofit` instance is built inside the class and never used. It can't be replaced with a fake in tests, and its client, timeouts and authentication can't be configured. The PR also adds no tests. — Define a `PaymentsApi` Retrofit interface and pass it into `PaymentService` through the constructor. Build Retrofit and OkHttp in the DI module. Add tests with MockWebServer covering success, an HTTP error and a network failure.
- [MINOR] 15 — `amount: Int` doesn't say which currency or unit it is in (for example cents or whole units), which invites mistakes with money. — Use a value type such as `Money(amountMinor: Long, currency: String)`.

## Questions for the author
- Line 16 says the key goes in the `Authorization` header. Is there a backend endpoint or proxy that should own payment authentication, so the app never holds a secret key?
- Once implemented, how will repeated charges be prevented? For example, will the request send an idempotency key so a retry after a timeout doesn't charge the rider twice?
- The description says this charges a "saved card". Where is the card `token` stored? It should be in Keystore or EncryptedSharedPreferences, and never logged, including by any future logging interceptor.

## Verdict
Request changes

## Summary
This PR adds `PaymentService`, a Kotlin class with an inline Retrofit client for the payments API and an empty `charge()` method. It commits a live secret key, and the charge logic is not implemented. Findings: 1 BLOCKER, 1 MAJOR, 2 MINOR.
