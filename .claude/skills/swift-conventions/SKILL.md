---
name: swift-conventions
description: "Skill for swift programming language conventions that triggers by .swift"
---

### 1. Naming Conventions
Severity: MAJOR
Use descriptive and meaningful names that follow Swift naming conventions. Types and protocols must use UpperCamelCase, while variables, functions, and properties must use lowerCamelCase. Avoid unclear abbreviations and single-letter names.
### 2. Concurrency and Thread Safety
Severity: CRITICAL
Ensure thread safety when accessing shared mutable state. Perform UI updates exclusively on the main thread or within @MainActor-isolated code. Prefer Swift concurrency (async/await) over blocking operations.
### 3. UIKit and SwiftUI Usage
Severity: MAJOR
Follow the project's established UI framework and architecture. Avoid unnecessary mixing of UIKit and SwiftUI. When interoperability is required, use appropriate integration mechanisms such as UIHostingController or UIViewRepresentable.


### Compliant Swift snippet
```swift
import SwiftUI

@MainActor
final class UserProfileViewModel: ObservableObject {
    @Published var userName = ""

    func updateUserName() async {
        userName = await fetchUserName()
    }
}

struct UserProfileView: View {
    let userName: String

    var body: some View {
        Text(userName)
    }
}
```

### Non-compliant Swift snippet
```swift
import SwiftUI

class usrVM {
    var n = ""

    func update() {
        DispatchQueue.global().sync {
            n = "John"
        }
    }
}

struct usrView: View {
    var body: some View {
        let view = Text("John")
        return view
    }
}
```