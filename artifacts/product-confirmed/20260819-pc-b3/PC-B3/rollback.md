# PC-B3 Rollback

1. Revert iOS `e72eca3b` and the Backend PC-B3 functional change introduced by `873284b`, then rebuild the affected targets and API service.
2. Keep migration `0099` applied. It is additive and may remain unused; do not run a destructive down migration.
3. Do not delete or rewrite Echo answers, Citation audit records, Context traces or formal memories.
4. Re-run `/ready`, the production PostgreSQL Owner Truth smoke, route authentication smoke and public Echo UI static gate.
5. Record that rollback removes PC-B3 Grounding audit completion and returns GAP-06 to `PARTIAL`.
