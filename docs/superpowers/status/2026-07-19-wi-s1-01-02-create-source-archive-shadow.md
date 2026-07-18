# WI-S1-01-02: CreateSource And Archive Shadow Evidence

Date: 2026-07-19

## Implemented Scope

This work item implements the first Owner Truth source command path while
keeping legacy Archive as the public authority:

- Backend commit `9080490` adds stable text `CreateSource` commands with
  `commandId`, `expectedVersion`, idempotent receipt replay, and an immutable
  Owner Truth Source payload.
- `POST /archive/items` mirrors only legacy text items into the non-authority
  Owner Truth shadow lane and returns an observable `ownerTruthShadow`
  result.
- The iOS local commit `b91fe1c` treats photo items as device-local. Photos
  do not enter Archive backend sync, do not claim uploaded/verified status,
  and cannot be pushed through the repository's direct sync helper.
- Existing text and time-letter metadata behavior remains unchanged.

## Evidence

### G0: Code And Contract

- `Scripts/QA/product-v4/run-owner-truth-create-source-gate.sh` passed.
- The gate verifies the text-only facade, local-only photo state, both Archive
  add/update call sites, the direct-sync guard, command fields, migration, and
  immutable receipt constraints.
- `swift test` passed through the gate.
- `Scripts/QA/product-v4/run-ios-test-foundation-gate.sh` passed, including
  the generic iPhoneOS hosted XCTest build with code signing disabled.
- `scripts/verify_backend.sh` passed.
- Both repositories passed `git diff --check` before commit.

### G2: Deployed Postgres

- Backend `9080490` was pushed to `main` and deployed on `miao-server`.
- Migration head advanced to `0012` and `/ready` returned `status=ready`.
- The deployed API container ran
  `scripts/run-backend-owner-truth-postgres-smoke.sh` successfully. It
  verifies CreateSource replay/immutability, Archive text shadowing, media
  local-only behavior, and legacy table preservation in an isolated database.

### G1: Explicitly Open

The Registry declares G1 for this work item. This slice changes no public
screen, and the complete app is still unavailable to the simulator because the
current Provider SDK binaries do not expose a runnable simulator slice. The
generic iPhoneOS hosted XCTest build is G0 evidence, not a substitute for G1.
Accordingly the work item is implemented with G0/G2 evidence; its G1 status
remains `EXTERNAL_BLOCKED` rather than being inferred as complete.

## Boundaries Preserved

- No Owner Truth read or authority cutover is enabled.
- No public UI or Stitch visual behavior changed.
- No photo/media upload implementation was added.
- The existing mixed handoff file remains intentionally unstaged; this file is
  the standalone evidence record for the work item.

## Next Work

The next plan slice remains the async Effect Kernel (`WI-S1-02-01`) unless a
new authority dependency changes the registered execution order. Candidate
promotion and any Owner Truth read path remain blocked behind later gates.
