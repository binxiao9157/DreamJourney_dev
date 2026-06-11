# Privacy Scope Implementation Report

Date: 2026-06-11

## Scope

Implemented the phase 2 minimum verifiable Memory Privacy Scope model and policy in:

- `DreamJourney/Sources/Services/Privacy/MemoryPrivacyScope.swift`
- `Scripts/PrivacyScopeVerify/main.swift`

## TDD Evidence

RED command:

```sh
xcrun swiftc DreamJourney/Sources/Services/Privacy/MemoryPrivacyScope.swift Scripts/PrivacyScopeVerify/main.swift -o /tmp/dreamjourney_privacy_scope_verify && /tmp/dreamjourney_privacy_scope_verify
```

RED result:

```text
<unknown>:0: error: error opening input file 'DreamJourney/Sources/Services/Privacy/MemoryPrivacyScope.swift' (No such file or directory)
```

GREEN command:

```sh
xcrun swiftc DreamJourney/Sources/Services/Privacy/MemoryPrivacyScope.swift Scripts/PrivacyScopeVerify/main.swift -o /tmp/dreamjourney_privacy_scope_verify && /tmp/dreamjourney_privacy_scope_verify
```

GREEN result:

```text
PrivacyScope verification passed
```

## Notes

- `privateOnly` denies all listed use surfaces.
- `localOnly` denies outward surfaces and only allows `timeMailboxEcho`.
- `generationAllowed` allows only `remoteExtraction`, `prompt`, and `memoirGeneration`.
- `familyCircle` allows only `careDashboard` and `familySync`.
- Unknown raw scope or surface values are denied by `PrivacyScopePolicy.canUse(scopeRawValue:surfaceRawValue:)`.
- Legacy `isPrivate` migration maps `true` to `privateOnly` and `false` or unknown to `localOnly`.
