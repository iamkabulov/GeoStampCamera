## Findings

### src/CheckoutViewModel.kt
- [BLOCKER] 11, 16 — A live client secret (value redacted, `sk-live-` prefix) is written into the code as a public `val`, and line 16 sends it in the body of every order request. It is in git history and the APK, where anyone can extract it, and it can also leak through proxies and request logs. — Revoke and rotate the key now, since it is already in git history. Remove it from the client and the request body. Authenticate order submission with a per-user session token in the `Authorization` header, added by an auth interceptor.
- [BLOCKER] 16 — `"/orders/{orderId}/submit"` is an ordinary string, not a Kotlin template, so the text `{orderId}` is sent as-is and `orderId` is never used. Every submission goes to the wrong path, so checkout can't complete an order. — Use `"/orders/$orderId/submit"`, or better, build the path in a repository with path-segment encoding.
- [MAJOR] 15 — `GlobalScope.launch` isn't tied to the ViewModel's lifecycle. The request isn't cancelled when the screen is closed, and an exception from `apiClient.post` goes uncaught and can crash the app. — Use `viewModelScope.launch` with `try/catch`, rethrowing `CancellationException`, and remove the `GlobalScope` import on line 4.
- [MAJOR] 13–18 — `submitOrder` returns nothing and updates no state, so the UI can't show loading, success or failure. A double tap submits the order twice. — Expose `StateFlow<CheckoutUiState>` (`Idle`, `Loading`, `Success`, `Error`) and ignore new submissions while one is loading.
- [MINOR] 8, 16 — The ViewModel calls `ApiClient` directly with a raw endpoint string and skips the repository layer, so it can't be unit-tested with a fake. The PR adds no tests. — Add an `OrderRepository` interface (`suspend fun submitOrder(id: String): Result<Unit>`), inject it in place of `ApiClient`, and add ViewModel tests.

### src/CouponView.swift
- [MAJOR] 7–9 — The coupon logic lives in the View as a method that `body` never calls, and it returns its result through an `@escaping` completion with a bare `Bool`. It can't be tested, can't be cancelled, and can't report why a code was rejected. — Move it into a `@MainActor` `CouponViewModel` that depends on an injected `CouponRepository` protocol with `func applyCoupon(code: String) async throws -> CouponResult`. Have the View only show the ViewModel's state.
- [MINOR] 7 — `ApplyCoupon` starts with a capital letter. Functions should be lowerCamelCase. — Rename it to `applyCoupon`.

## Questions for the author
- `ApplyCoupon` accepts any non-empty code. Is this a placeholder, and will codes be checked by the backend, with length and character limits on the client?
- Does `ApiClient` already add authentication and enforce HTTPS? If it adds auth, the `"secret"` body field is unnecessary, but the hardcoded key still has to be rotated.
- How do `CouponView` and `CheckoutViewModel` connect? Nothing in the diff connects them, so the checkout flow described in the PR isn't assembled yet.
- Which iOS version does the coupon feature target? That decides between `@Observable` and `ObservableObject` for the new ViewModel.

## Verdict
Request changes

## Summary
This PR adds a Kotlin `CheckoutViewModel` that submits orders from `GlobalScope`, and a SwiftUI `CouponView` with a placeholder coupon check. The checkout code commits a live secret and sends it in the request body, and order submission targets the wrong path. Findings: 2 BLOCKER, 3 MAJOR, 2 MINOR.
