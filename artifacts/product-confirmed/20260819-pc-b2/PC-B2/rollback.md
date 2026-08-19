# PC-B2 Rollback

1. Revert Backend to `d0718b7` and rebuild/restart the API service.
2. Do not delete or rewrite MemoryVersion, SearchDocument, Projection, DecisionReceipt or Citation audit records.
3. No database down migration is required because PC-B2 added no migration.
4. Re-run `/ready` and the production PostgreSQL Owner Truth smoke after rollback.
5. Record that rollback restores citation-order Owner Context and does not represent query-ranked completion.
