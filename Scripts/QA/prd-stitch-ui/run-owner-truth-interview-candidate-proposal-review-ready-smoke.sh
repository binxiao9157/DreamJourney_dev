#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SMOKE_VARIANT=review-ready \
SMOKE_ID=owner-truth-interview-candidate-proposal-review-ready-smoke \
LAUNCH_SCENARIO=DJRunOwnerTruthInterviewCandidateProposalReviewReadySmoke \
RESULT_FILE_NAME=owner-truth-interview-candidate-proposal-review-ready-smoke-result.json \
COMPLETION_PATTERN="OwnerTruthInterviewCandidateProposalReviewReadySmoke completed" \
"$SCRIPT_DIR/run-owner-truth-interview-natural-input-product-surface-smoke.sh"
