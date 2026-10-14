# Family command policy-expiry repair — checkpoint

Date: 2026-10-15. Base: 5db26693. Backend unchanged at 3b02e45.

Family mutations refresh only an expired/missing policy once before submission, revalidate account/permission, and never add replay of an unknown write outcome. The two family metadata reads use a fresh policy decision. UI retains page-local inputs after failure, rejects cross-account/duplicate submissions, shows complete errors, and refreshes the member list after success. Shared request/auth/recovery, Live SDK/audio and memory persistence were not rewritten.

Validation: final local 65 passed, 0 failed, 0 skipped; same-assertion expired command and read-after-write red/green evidence. Normal simulator waited over 300 seconds and created one invitation with updated list. USB original-place install retained login/data. Physical invitation acceptance after over 345 seconds passed. Family Live adopted the authorized synthetic fact, user confirmed normal mic/audio, and neither account gained memories from the read-only dialogue. Own short scene saved two user turns/four messages and one complete pending theme; user confirmed completion status and both pending/biography pages normal.

Overall acceptance remains incomplete. Open findings:
- Family typed Echo failed before any observed answer POST; ordinary restart then succeeded. Exact first cause remains unproven.
- Revoking a grant removed the family from the list, but Echo did not automatically return to self; manual selection succeeded. Next repair: DJ-FAMILY-REVOKE-CONTEXT-20261015.
- Candidate facet numeric decoding can show an unreadable-supplement warning; primary facts remained correct. Separately tracked.

This checkpoint does not claim new-version natural ten-minute validation, regrant, revoked stale-context request rejection, or own short formal confirmation/cold read. Previous results retain their original versions. No user memory cleanup or logout. Raw device/account evidence remains in the private local evidence archive; this document contains no credentials or invitation codes.
