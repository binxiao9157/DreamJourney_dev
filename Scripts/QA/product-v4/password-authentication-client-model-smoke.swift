import Foundation

@main
enum PasswordAuthenticationClientModelSmoke {
    static func main() {
        let capability = BackendPasswordAuthenticationCapability(json: [
            "implemented": true,
            "enabled": true,
            "ready": true,
            "loginReady": true,
            "changeReady": true,
            "setupReady": true,
            "resetReady": true,
            "reauthReady": true,
            "loginEndpoint": "/v2/auth/password/login",
            "setupEndpoint": "/v2/auth/password/setup",
            "changeEndpoint": "/v2/auth/password/change",
            "resetEndpoint": "/v2/auth/password/reset",
            "resetChallengePurpose": "passwordReset",
            "reauthChallengePurpose": "sensitiveOperation",
            "minLength": 8,
            "maxLength": 128,
            "maxAttempts": 5,
            "lockoutSeconds": 900,
            "sessionContractVersion": 2,
            "contractVersion": 2,
        ])
        precondition(capability.canLogin)
        precondition(capability.canSetupPassword)
        precondition(capability.canChangePassword)
        precondition(capability.canResetPassword)
        precondition(capability.canManagePassword)

        let passwordOnly = BackendPasswordAuthenticationCapability(json: [
            "implemented": true,
            "enabled": true,
            "ready": true,
            "loginReady": true,
            "changeReady": true,
            "setupReady": false,
            "resetReady": false,
            "reauthReady": false,
            "loginEndpoint": "/v2/auth/password/login",
            "setupEndpoint": "/v2/auth/password/setup",
            "changeEndpoint": "/v2/auth/password/change",
            "resetEndpoint": "/v2/auth/password/reset",
            "resetChallengePurpose": "passwordReset",
            "reauthChallengePurpose": "sensitiveOperation",
            "minLength": 8,
            "maxLength": 128,
            "maxAttempts": 5,
            "lockoutSeconds": 900,
            "sessionContractVersion": 2,
            "contractVersion": 2,
        ])
        precondition(passwordOnly.canLogin)
        precondition(passwordOnly.canChangePassword)
        precondition(!passwordOnly.canSetupPassword)
        precondition(!passwordOnly.canResetPassword)

        var changeDisabledJSON: [String: Any] = [
            "implemented": true,
            "enabled": true,
            "ready": true,
            "loginReady": true,
            "changeReady": false,
            "setupReady": false,
            "resetReady": false,
            "reauthReady": false,
            "loginEndpoint": "/v2/auth/password/login",
            "setupEndpoint": "/v2/auth/password/setup",
            "changeEndpoint": "/v2/auth/password/change",
            "resetEndpoint": "/v2/auth/password/reset",
            "resetChallengePurpose": "passwordReset",
            "reauthChallengePurpose": "sensitiveOperation",
            "minLength": 8,
            "maxLength": 128,
            "maxAttempts": 5,
            "lockoutSeconds": 900,
            "sessionContractVersion": 2,
            "contractVersion": 2,
        ]
        let changeDisabled = BackendPasswordAuthenticationCapability(json: changeDisabledJSON)
        precondition(changeDisabled.canLogin)
        precondition(!changeDisabled.canChangePassword)
        changeDisabledJSON["changeReady"] = true
        precondition(
            BackendPasswordAuthenticationCapability(json: changeDisabledJSON).canChangePassword
        )

        let incomplete = BackendPasswordAuthenticationCapability(json: [
            "implemented": true,
            "enabled": true,
            "ready": true,
            "loginReady": true,
            "contractVersion": 2,
        ])
        precondition(!incomplete.canLogin)
        precondition(!incomplete.canManagePassword)

        let expiresAt = ISO8601DateFormatter().string(from: Date().addingTimeInterval(300))
        let token = BackendPasswordActionTokenContract(json: [
            "status": "verified",
            "actionToken": "action_test_token",
            "action": "passwordReset",
            "expiresAt": expiresAt,
            "contractVersion": 2,
        ], expectedAction: .passwordReset)
        precondition(token?.action == .passwordReset)
        precondition(token?.isExpired == false)
        precondition(BackendPasswordActionTokenContract(json: [
            "status": "verified",
            "actionToken": "action_test_token",
            "action": "sensitiveOperation",
            "expiresAt": expiresAt,
            "contractVersion": 2,
        ], expectedAction: .passwordReset) == nil)

        let login = BackendPasswordLoginContract(json: [
            "status": "authenticated",
            "user": ["id": "user-1"],
            "auth": ["userId": "user-1"],
            "password": [
                "configured": true,
                "passwordRevision": 1,
                "contractVersion": 2,
            ],
            "contractVersion": 2,
        ])
        precondition(login?.userId == "user-1")
        precondition(BackendPasswordLoginContract(json: [
            "status": "authenticated",
            "user": ["id": "user-1"],
            "auth": ["userId": "user-1"],
            "contractVersion": 1,
        ]) == nil)

        let changed = BackendPasswordMutationContract(json: [
            "status": "changed",
            "password": [
                "configured": true,
                "passwordRevision": 2,
                "contractVersion": 2,
            ],
            "auth": ["accessToken": "new-access-token"],
            "sessionRevocation": [
                "revokedFamilyCount": 1,
                "revokedSessionCount": 2,
            ],
            "contractVersion": 2,
        ], expectedAction: .change)
        precondition(changed?.passwordRevision == 2)
        precondition(changed?.revokedFamilyCount == 1)
        precondition(changed?.revokedSessionCount == 2)

        let reset = BackendPasswordMutationContract(json: [
            "status": "resetAccepted",
            "loginRequired": true,
            "contractVersion": 2,
        ], expectedAction: .reset)
        precondition(reset?.loginRequired == true)
        precondition(reset?.passwordRevision == nil)

        print("Password authentication client model smoke passed")
    }
}
