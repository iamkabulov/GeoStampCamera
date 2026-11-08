## Findings

### src/ProfileViewModel.swift
- [MAJOR] 10–11 — `URLSession` runs the `dataTask` callback on a background queue, and `completion` is called there directly. The class isn't `@MainActor`, so any caller that updates the UI or `loading` from the callback does it off the main thread. That is a data race and can crash UIKit. — Mark the ViewModel `@MainActor` and switch to `func fetchProfile(id:) async throws -> Profile` using `URLSession.shared.data(from:)`. If you keep the callback, switch to the main queue before calling `completion`.
- [MAJOR] 10–11 — The `response` and `error` arguments are thrown away (`_, _`). Network errors, non-2xx responses and bad response data all become `nil`, so the caller can't show a useful error. An error page from the server is also passed to `Profile.init`. — Check `error` and that the `HTTPURLResponse` status is 2xx, decode with `JSONDecoder`, and put the failure in view state, for example a `Loadable<Profile>` with a `.failed` case.
- [MAJOR] 10 — The ViewModel calls `URLSession.shared` and the free function `profileURL(_:)` directly and has no injected dependency. Its fetch logic can't be unit-tested without real network calls, and the PR adds no tests. — Add a `ProfileRepository` protocol, inject it through `init`, and add `ProfileViewModelTests` with a fake repository for the success and failure cases.
- [MINOR] 9 — `FetchProfile` starts with a capital letter. Functions should be lowerCamelCase. — Rename it to `fetchProfile`.
- [MINOR] 6 — `loading` is never set in this diff, so it stays `false`. It can be changed from outside the class, and its name lacks the `is` prefix used for booleans. — Rename it to `@Published private(set) var isLoading`, or `private(set)` if the class doesn't use `@Published`, and set it around the fetch. Better, replace it with a single state value.
- [MINOR] 1 — `import UIKit` isn't needed. Nothing in the file uses a UIKit type. — Use `import Foundation`.
- [MINOR] 12 — The `dataTask` is not stored, so the request can't be cancelled. `completion` still runs after the screen is closed. — Use async/await from `.task` or a stored `Task`, or keep the `URLSessionDataTask` and cancel it on teardown.

## Questions for the author
- How does `profileURL(_:)` build the URL, and is it always `https://`? If it puts `id` into the URL by plain string insertion, an `id` containing `/`, `?` or `#` could change the request. An `http://` URL would be a blocker.
- Line 3 says this screen is written in UIKit "instead of SwiftUI". Is that on purpose? Which UI framework and async style (callbacks or async/await) does the rest of the repo use?
- The description says this PR adds "the profile screen and its view model", but the diff has only the ViewModel. Where is the view or view controller, and how is the ViewModel created?
- Does `Profile` hold personal data, and does the profile endpoint need authentication? No token handling appears in this file.

## Verdict
Request changes

## Summary
This PR adds a UIKit-era `ProfileViewModel` that fetches a profile with `URLSession.shared` and returns it through a completion handler. The main problems are that the result comes back on a background queue and that every failure is silently turned into `nil`. Findings: 0 BLOCKER, 3 MAJOR, 4 MINOR. The view or view controller and the `profileURL`/`Profile` code could not be reviewed because they are not in the diff.
