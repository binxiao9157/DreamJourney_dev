# PC-B1 Rollback

1. Disable the `ownerTruthCandidateReview` release-policy feature for public clients.
2. Revert the iOS formal-memory entry and client commit if a binary rollback is required.
3. Revert Backend `d0718b7` and `ae670ea`, rebuild `api`, and verify `/ready`.
4. Do not delete or rewrite MemoryVersion, DecisionReceipt, Source, Candidate, correction-link, or PublicationVersion rows created before rollback.
5. Re-run the route ownership and release-policy inventories after rollback.
