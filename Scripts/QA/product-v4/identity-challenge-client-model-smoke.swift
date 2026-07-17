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
            "contractVersion": 1,
        ])
        precondition(synthetic.enabled)
        precondition(synthetic.providerMode == "synthetic")
        precondition(!synthetic.productionReady)
        precondition(synthetic.clientFlowEnabled)
        precondition(synthetic.canStartClientFlow)

        let challenge = BackendIdentityChallengeContract(json: [
            "status": "accepted",
            "challenge": [
                "challengeId": "challenge_test",
                "purpose": "login",
                "deliveryMode": "acceptedOnly",
                "expiresAt": "2030-07-17T06:00:00.123456+00:00",
                "retryAfterSeconds": 30,
                "productionReady": false,
                "contractVersion": 1,
            ],
        ])
        precondition(challenge?.challengeId == "challenge_test")
        precondition(challenge?.retryAfterSeconds == 30)
        precondition(challenge?.productionReady == false)

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
