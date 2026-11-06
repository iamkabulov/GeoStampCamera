---
name: kotlin-conventions
description: Kotlin coding conventions for Android code. Load whenever reading, writing, or reviewing .kt files (and .kts build scripts) — including when the review-pr workflow checks changed Kotlin files.
---

# Kotlin conventions

Apply these rules to every `.kt` file. Each rule has a severity used by reviews: CRITICAL maps to BLOCKER in the PR review output.

### 1. Naming Conventions
Severity: MAJOR
Follow the official Kotlin naming style. Classes, interfaces, and objects use UpperCamelCase; functions, properties, and local variables use lowerCamelCase; `const val` and top-level immutable constants use SCREAMING_SNAKE_CASE. Name a backing property with a leading underscore only when it backs a public property (`_uiState` / `uiState`). Avoid unclear abbreviations and single-letter names outside short lambdas.

### 2. Coroutines and Threading
Severity: CRITICAL
Never use `GlobalScope` or `runBlocking` in app code. Launch work in a lifecycle-bound scope (`viewModelScope`, `lifecycleScope`) and use structured concurrency. Make suspend functions main-safe: move blocking or I/O work off the main thread with `withContext(Dispatchers.IO)` (or an injected dispatcher), and never call `Thread.sleep` on the main thread. Do not swallow `CancellationException` in `catch` blocks.

### 3. Jetpack and Lifecycle
Severity: MAJOR
Keep state in a `ViewModel` and expose it as an immutable `StateFlow`/`LiveData`, keeping the mutable version private. Never hold a reference to an `Activity`, `Fragment`, `View`, or `Context` in a `ViewModel` (use `Application` context only if unavoidable). Collect flows in the UI with `repeatOnLifecycle(Lifecycle.State.STARTED)` or `collectAsStateWithLifecycle()` so collection stops when the UI is not visible. In Fragments, observe with `viewLifecycleOwner`, not `this`.

### Compliant Kotlin snippet
```kotlin
class UserProfileViewModel(
    private val repository: UserRepository,
    private val ioDispatcher: CoroutineDispatcher = Dispatchers.IO,
) : ViewModel() {

    private val _userName = MutableStateFlow("")
    val userName: StateFlow<String> = _userName.asStateFlow()

    fun loadUserName() {
        viewModelScope.launch {
            _userName.value = withContext(ioDispatcher) { repository.fetchUserName() }
        }
    }
}

class UserProfileFragment : Fragment(R.layout.fragment_user_profile) {
    private val viewModel: UserProfileViewModel by viewModels()

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        viewLifecycleOwner.lifecycleScope.launch {
            viewLifecycleOwner.repeatOnLifecycle(Lifecycle.State.STARTED) {
                viewModel.userName.collect { binding.userNameText.text = it }
            }
        }
    }
}
```

### Non-compliant Kotlin snippet
```kotlin
class usrVM(val ctx: Activity) : ViewModel() {   // bad name, leaks Activity
    val n = MutableStateFlow("")                  // exposes mutable state, unclear name

    fun update() {
        GlobalScope.launch {                      // unscoped coroutine, outlives the ViewModel
            n.value = runBlocking { api.fetch() } // blocks a thread
        }
    }
}

class usrFragment : Fragment() {
    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        lifecycleScope.launch {                   // Fragment lifecycle, not view lifecycle
            usrVM(requireActivity()).n.collect {  // collects even while stopped
                Thread.sleep(500)                 // blocks the main thread
            }
        }
    }
}
```
