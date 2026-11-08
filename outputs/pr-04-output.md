## Findings

### src/TripViewModel.kt
- [BLOCKER] 19 — `"/users/{userId}/trips"` is an ordinary string, not a Kotlin template, so the text `{userId}` is sent as-is and the `userId` parameter is never used. Every request goes to the wrong path, so no rider's trips load. — Use `"/users/$userId/trips"`, or better, let a repository or a typed API method with a path parameter build the path so the ID is URL-encoded.
- [MAJOR] 19 — Nothing catches errors from `apiClient.get(...)`. If it throws, for example when offline, on an HTTP error, a timeout or bad response data, the exception goes uncaught in `viewModelScope.launch` and crashes the app. — Wrap the call in `try/catch`, rethrowing `CancellationException`, or have the repository return a `Result`. Then turn failures into UI state.
- [MAJOR] 10, 19 — The ViewModel calls `ApiClient` directly and skips the repository layer, as the comment on line 18 admits. Endpoint details live in the presentation layer, and the ViewModel can't be unit-tested without faking HTTP. The PR also adds no tests. — Add a `TripRepository` interface (`suspend fun getTrips(userId: String): List<Trip>`) with an implementation that uses `ApiClient`, and inject the interface. Add a ViewModel test with a fake repository and a test dispatcher.
- [MINOR] 13–14 — State is a bare `List<Trip>` that starts as `emptyList()`, so the UI can't tell loading, empty and failed apart. A failed load looks like "no trips". — Expose a sealed `TripsUiState` (`Loading`, `Success`, `Error`) instead.
- [MINOR] 14 — `trips` is assigned `_trips` directly, so a consumer could cast it back to `MutableStateFlow` and change it. — Use `_trips.asStateFlow()`.
- [MINOR] 16–20 — Each `loadTrips` call starts a new coroutine without cancelling the previous one. Repeated calls send duplicate requests, and an older response can overwrite a newer one. — Keep the `Job` and cancel it before starting a new one, or skip the call while a load is already running.

## Questions for the author
- What is the signature of `ApiClient.get`? Does it return a typed, deserialized `List<Trip>`, and is it safe to call from the main thread, for example by moving to `Dispatchers.IO` internally?
- Does the backend check that the authenticated user matches `userId`? If it doesn't, any rider could request another rider's trips. Would a `/me/trips` endpoint, or taking the ID from an injected session, be better?
- The description says this adds a "trip list screen", but the diff has only the ViewModel. Where is the screen, and how is `ApiClient` given to the ViewModel (Hilt or a factory)?

## Verdict
Request changes

## Summary
This PR adds `TripViewModel`, which loads a rider's trips by calling `ApiClient` directly from `viewModelScope` into a `StateFlow`. The trips path never includes the user ID, so the feature can't work as written, and any API error crashes the app. Findings: 1 BLOCKER, 2 MAJOR, 3 MINOR.
