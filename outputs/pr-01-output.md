## Findings

### src/RideHistoryViewModel.swift
- [MAJOR] 17 — `try?` swallows every error from `recentRides()` and assigns `[]` instead. A failed load (offline, decode error) looks the same as "no rides yet", and the user gets no error or retry. A refresh that fails also wipes rides that were already loaded. — Catch the error and store it in view state. For example, use a single `Loadable<[Ride]>` (`.idle / .loading / .loaded / .failed`) or add an `errorMessage` field, and keep the previous rides when a load fails.
- [MINOR] 14–18 — Nothing stops `loadRides()` from running twice at once, for example from `.task` and pull-to-refresh. The first call's `defer` sets `isLoading = false` while the second is still running, and the older response can overwrite the newer one. — Add `guard !isLoading else { return }`, or keep one `Task` handle and cancel the previous load.
- [MINOR] 17 — `try?` also swallows `CancellationError`. If SwiftUI cancels the `.task` when the view disappears, the list is still set to `[]`. — Catch `CancellationError` separately and leave the state unchanged.
- [MINOR] 5–6 — `rides` and `isLoading` can be set from outside the class, so a view could change them directly. — Mark both `@Published private(set) var`.
- [MINOR] 1 — `import SwiftUI` ties the ViewModel to the UI framework, although it only needs `ObservableObject` and `@Published`. — Use `import Foundation` and `import Combine` instead.
- [MINOR] 14–18 — The new loading logic has no tests. — Add `RideHistoryViewModelTests` with a fake `RideRepository` that covers success, failure, and the double-load guard.

## Questions for the author
- The description says this PR adds a SwiftUI screen, but the diff has only the ViewModel. Where is the View, and where is the ViewModel created and given its `RideRepository`?
- Is `RideRepository` a protocol, and is it `Sendable`? Does `recentRides()` do its I/O off the main actor? If it is a concrete class, tests can't swap in a fake. If it does synchronous work, it will block the main actor.
- `Ride` records may contain location data such as routes or addresses. The `Ride` and `RideRepository` code isn't in this diff, so how they store and send that data needs a separate privacy review.

## Verdict
Request changes

## Summary
This PR adds `RideHistoryViewModel`, a `@MainActor` `ObservableObject` that loads recent rides through an injected `RideRepository` using async/await. The main problem is that load failures are silently shown as an empty list. The rest are hardening, encapsulation and test-coverage items. Findings: 0 BLOCKER, 1 MAJOR, 5 MINOR. The security and style reviewers found nothing, and the View and `RideRepository` code could not be reviewed because they are not in the diff.
