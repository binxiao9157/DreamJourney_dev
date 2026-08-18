import Foundation

@main
enum IdentityChallengeClientModelSmoke {
    static func main() {
        let unavailable = BackendIdentityChallengeCapability(json: nil)
        precondition(!unavailable.enabled)
        precondition(!unavailable.productionReady)
        precondition(!unavailable.clientFlowEnabled)
        precondition(!unavailable.canStartClientFlow)

        let synthetic = BackendIdentityChallengeCapability(json: [
            "enabled": true,
            "providerMode": "synthetic",
            "productionReady": false,
            "clientFlowEnabled": true,
            "challengeEndpoint": "/v2/auth/challenges",
            "verifyEndpointTemplate": "/v2/auth/challenges/{challengeId}/verify",
            "statusEndpointTemplate": "/v2/auth/challenges/{challengeId}",
            "stateContractVersion": 1,
            "deliveryReceiptSupported": true,
            "deliveryRecoverySupported": true,
            "contractVersion": 1,
        ])
        precondition(synthetic.enabled)
        precondition(synthetic.providerMode == "synthetic")
        precondition(!synthetic.productionReady)
        precondition(synthetic.clientFlowEnabled)
        precondition(synthetic.canStartClientFlow)
        precondition(synthetic.canReadChallengeState)

        let restrictedTestAllowlist = BackendIdentityChallengeCapability(json: [
            "enabled": true,
            "providerMode": "testAllowlist",
            "productionReady": false,
            "clientFlowEnabled": true,
            "challengeEndpoint": "/v2/auth/challenges",
            "verifyEndpointTemplate": "/v2/auth/challenges/{challengeId}/verify",
            "statusEndpointTemplate": "/v2/auth/challenges/{challengeId}",
            "stateContractVersion": 1,
            "deliveryReceiptSupported": false,
            "deliveryRecoverySupported": false,
            "testAccountFlowEnabled": true,
            "testAccountTargetRestricted": true,
            "contractVersion": 1,
        ])
        precondition(restrictedTestAllowlist.canStartClientFlow)

        let unrestrictedTestAllowlist = BackendIdentityChallengeCapability(json: [
            "enabled": true,
            "providerMode": "testAllowlist",
            "productionReady": false,
            "clientFlowEnabled": true,
            "challengeEndpoint": "/v2/auth/challenges",
            "verifyEndpointTemplate": "/v2/auth/challenges/{challengeId}/verify",
            "testAccountFlowEnabled": true,
            "testAccountTargetRestricted": false,
            "contractVersion": 1,
        ])
        precondition(!unrestrictedTestAllowlist.canStartClientFlow)

        let challenge = BackendIdentityChallengeContract(json: [
            "status": "accepted",
            "challenge": [
                "challengeId": "challenge_test",
                "purpose": "login",
                "deliveryMode": "acceptedOnly",
                "challengeState": "active",
                "deliveryState": "accepted",
                "attempt": 0,
                "maxAttempts": 5,
                "remainingAttempts": 5,
                "expiresAt": "2030-07-17T06:00:00.123456+00:00",
                "retryAfterSeconds": 30,
                "recoveryState": "available",
                "recoveryAttempt": 0,
                "statusEndpoint": "/v2/auth/challenges/challenge_test",
                "productionReady": false,
                "stateContractVersion": 1,
                "contractVersion": 1,
            ],
        ])
        precondition(challenge?.challengeId == "challenge_test")
        precondition(challenge?.retryAfterSeconds == 30)
        precondition(challenge?.productionReady == false)
        precondition(challenge?.deliveryState == .accepted)
        precondition(challenge?.remainingAttempts == 5)
        precondition(challenge?.recoveryState == .available)

        let passwordResetChallenge = BackendIdentityChallengeContract(json: [
            "status": "accepted",
            "challenge": [
                "challengeId": "challenge_password_reset",
                "purpose": "passwordreset",
                "deliveryMode": "acceptedOnly",
                "expiresAt": "2030-07-17T06:00:00Z",
                "contractVersion": 1,
            ],
        ])
        precondition(passwordResetChallenge?.purpose == "passwordReset")

        let sensitiveOperationChallenge = BackendIdentityChallengeContract(json: [
            "status": "accepted",
            "challenge": [
                "challengeId": "challenge_sensitive_operation",
                "purpose": "sensitiveoperation",
                "deliveryMode": "acceptedOnly",
                "expiresAt": "2030-07-17T06:00:00Z",
                "contractVersion": 1,
            ],
        ])
        precondition(sensitiveOperationChallenge?.purpose == "sensitiveOperation")

        let recovered = BackendIdentityChallengeStateContract(json: [
            "status": "available",
            "challenge": [
                "challengeId": "challenge_test",
                "purpose": "login",
                "deliveryMode": "acceptedOnly",
                "challengeState": "active",
                "deliveryState": "delivered",
                "attempt": 1,
                "maxAttempts": 5,
                "remainingAttempts": 4,
                "retryAfterSeconds": 30,
                "recoveryState": "notRequired",
                "recoveryAttempt": 1,
                "statusEndpoint": "/v2/auth/challenges/challenge_test",
                "expiresAt": "2030-07-17T06:00:00.123456+00:00",
                "productionReady": true,
                "stateContractVersion": 1,
                "contractVersion": 1,
            ],
        ])
        precondition(recovered?.state.deliveryState == .delivered)
        precondition(recovered?.state.attempt == 1)
        precondition(recovered?.state.recoveryAttempt == 1)

        let verified = BackendIdentityVerificationContract(json: [
            "status": "verified",
            "contractVersion": 1,
            "subject": [
                "subjectId": "sub_random",
                "bindingId": "binding_random",
                "proofReceiptId": "proof_random",
                "contractVersion": 1,
            ],
        ])
        precondition(verified?.subjectId == "sub_random")
        precondition(verified?.bindingId == "binding_random")
        precondition(verified?.proofReceiptId == "proof_random")

        precondition(BackendIdentityChallengeContract(json: [:]) == nil)
        precondition(BackendIdentityChallengeContract(json: [
            "status": "challengePending",
            "challenge": [
                "challengeId": "challenge_test",
                "purpose": "login",
                "deliveryMode": "acceptedOnly",
                "expiresAt": "2030-07-17T06:00:00Z",
                "contractVersion": 1,
            ],
        ]) == nil)
        precondition(BackendIdentityChallengeStateContract(json: [
            "status": "available",
            "challenge": [
                "challengeId": "challenge_test",
                "purpose": "login",
                "deliveryMode": "acceptedOnly",
                "challengeState": "active",
                "deliveryState": "delivered",
                "attempt": 1,
                "maxAttempts": 5,
                "remainingAttempts": 4,
                "retryAfterSeconds": 30,
                "recoveryState": "available",
                "recoveryAttempt": 1,
                "statusEndpoint": "/v2/auth/challenges/challenge_test",
                "expiresAt": "2030-07-17T06:00:00Z",
                "stateContractVersion": 1,
                "contractVersion": 1,
            ],
        ]) == nil)
        precondition(BackendIdentityChallengeContract(json: [
            "status": "accepted",
            "challenge": [
                "challengeId": "challenge_test",
                "purpose": "login",
                "deliveryMode": "acceptedOnly",
                "expiresAt": "2020-07-17T06:00:00Z",
                "contractVersion": 1,
            ],
        ]) == nil)
        precondition(BackendIdentityChallengeCapability(json: [
            "enabled": true,
            "providerMode": "synthetic",
            "clientFlowEnabled": true,
            "challengeEndpoint": "/v2/auth/challenges",
            "verifyEndpointTemplate": "/v2/auth/challenges/{challengeId}/verify",
            "contractVersion": 1,
        ]).canStartClientFlow == false)
        precondition(BackendIdentityChallengeCapability(json: [
            "enabled": true,
            "providerMode": "testAllowlist",
            "productionReady": false,
            "clientFlowEnabled": true,
            "challengeEndpoint": "/v2/auth/challenges",
            "verifyEndpointTemplate": "/v2/auth/challenges/{challengeId}/verify",
            "contractVersion": 1,
        ]).canStartClientFlow == false)
        precondition(BackendIdentityChallengeCapability(json: [
            "enabled": true,
            "providerMode": "synthetic",
            "productionReady": false,
            "clientFlowEnabled": true,
            "contractVersion": 2,
        ]).canStartClientFlow == false)
        precondition(BackendIdentityChallengeCapability(json: [
            "enabled": true,
            "providerMode": "synthetic",
            "clientFlowEnabled": true,
        ]).canStartClientFlow == false)
        precondition(BackendIdentityChallengeCapability(json: [
            "enabled": true,
            "providerMode": "synthetic",
            "clientFlowEnabled": true,
            "contractVersion": 1,
        ]).canStartClientFlow == false)
        precondition(BackendIdentityVerificationContract(json: [:]) == nil)
        print("Identity challenge client model smoke passed")
    }
}
