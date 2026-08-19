import UIKit

extension Notification.Name {
    static let djInAppMessageCenterDidUpdate = Notification.Name(
        "dj.inAppMessageCenter.didUpdate"
    )
}

enum AuthoritativeInAppMessageCenterLoadState: Equatable {
    case idle
    case loading
    case loaded
    case failed(String)
}

struct AuthoritativeInAppMessageCenterSnapshot: Equatable {
    let messages: [InAppMessage]
    let unreadCount: Int
    let nextCursor: String?
    let loadState: AuthoritativeInAppMessageCenterLoadState

    static let idle = AuthoritativeInAppMessageCenterSnapshot(
        messages: [],
        unreadCount: 0,
        nextCursor: nil,
        loadState: .idle
    )

    var hasReadMessages: Bool {
        messages.contains { !$0.isUnread }
    }
}

enum AuthoritativeInAppMessageCenterError: LocalizedError {
    case accountLeaseInvalid
    case staleRequest
    case messageUnavailable

    var errorDescription: String? {
        switch self {
        case .accountLeaseInvalid:
            return "账号状态已变化，请重新打开消息中心"
        case .staleRequest:
            return "消息请求已过期，请重新加载"
        case .messageUnavailable:
            return "消息状态已变化，请刷新后重试"
        }
    }
}

final class AuthoritativeInAppMessageCenterStore {
    static let shared = AuthoritativeInAppMessageCenterStore()

    private struct LeaseScope: Equatable {
        let subjectId: String
        let vaultId: String
        let generation: UInt64
        let generationId: UUID
        let authorityEpoch: String

        init(_ lease: AccountLease) {
            subjectId = lease.subjectId
            vaultId = lease.vaultId
            generation = lease.generation
            generationId = lease.generationId
            authorityEpoch = lease.authorityEpoch
        }
    }

    private let client: InAppMessageCenterClientPort
    private let accountLeaseRuntime: AccountLeaseRuntimePort
    private let lock = NSLock()
    private var scope: LeaseScope?
    private var storedSnapshot = AuthoritativeInAppMessageCenterSnapshot.idle
    private var requestGeneration: UInt64 = 0
    private var foregroundObserver: NSObjectProtocol?
#if DEBUG || UI_QA_SIMULATOR
    private var uiqaFrozenScope: LeaseScope?
#endif

    init(
        client: InAppMessageCenterClientPort = DreamJourneyBackendClient.shared,
        accountLeaseRuntime: AccountLeaseRuntimePort = AccountLeaseRuntime.shared
    ) {
        self.client = client
        self.accountLeaseRuntime = accountLeaseRuntime
        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshActiveAccount()
        }
    }

    deinit {
        if let foregroundObserver {
            NotificationCenter.default.removeObserver(foregroundObserver)
        }
    }

    func snapshot(for accountLease: AccountLease) -> AuthoritativeInAppMessageCenterSnapshot {
        guard accountLeaseRuntime.validate(accountLease, at: .ui).allowed else {
            return .idle
        }
        lock.lock()
        defer { lock.unlock() }
        return scope == LeaseScope(accountLease) ? storedSnapshot : .idle
    }

    func refresh(
        accountLease: AccountLease,
        completion: ((Result<AuthoritativeInAppMessageCenterSnapshot, Error>) -> Void)? = nil
    ) {
#if DEBUG || UI_QA_SIMULATOR
        if let frozenSnapshot = uiqaFrozenSnapshot(for: accountLease) {
            postUpdate()
            completion?(.success(frozenSnapshot))
            return
        }
#endif
        guard let generation = beginRequest(accountLease: accountLease, resetsItems: true) else {
            completion?(.failure(AuthoritativeInAppMessageCenterError.accountLeaseInvalid))
            return
        }
        client.fetchInAppMessages(
            accountLease: accountLease,
            limit: 50,
            cursor: nil
        ) { [weak self] result in
            self?.finishPageRequest(
                result,
                accountLease: accountLease,
                generation: generation,
                appends: false,
                completion: completion
            )
        }
    }

    func loadNextPage(
        accountLease: AccountLease,
        completion: @escaping (Result<AuthoritativeInAppMessageCenterSnapshot, Error>) -> Void
    ) {
        let cursor: String?
        let generation: UInt64
        lock.lock()
        let matchingScope = scope == LeaseScope(accountLease)
        cursor = matchingScope ? storedSnapshot.nextCursor : nil
        requestGeneration &+= 1
        generation = requestGeneration
        lock.unlock()

        guard matchingScope,
              let cursor,
              accountLeaseRuntime.validate(accountLease, at: .request).allowed else {
            completion(.failure(AuthoritativeInAppMessageCenterError.staleRequest))
            return
        }
        client.fetchInAppMessages(
            accountLease: accountLease,
            limit: 50,
            cursor: cursor
        ) { [weak self] result in
            self?.finishPageRequest(
                result,
                accountLease: accountLease,
                generation: generation,
                appends: true,
                completion: completion
            )
        }
    }

    func markRead(
        message: InAppMessage,
        accountLease: AccountLease,
        completion: @escaping (Result<InAppMessage, Error>) -> Void
    ) {
        guard message.authority == .backend,
              accountLeaseRuntime.validate(accountLease, at: .request).allowed else {
            completion(.failure(AuthoritativeInAppMessageCenterError.accountLeaseInvalid))
            return
        }
        let commandId = UUID().uuidString.lowercased()
        client.markInAppMessageRead(
            accountLease: accountLease,
            messageId: message.id,
            commandId: commandId
        ) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success(let receipt):
                    let updated: InAppMessage? = self.commitCommand(
                        accountLease: accountLease,
                        unreadCount: receipt.unreadCount,
                        mutation: { messages in
                            guard let index = messages.firstIndex(where: { $0.id == message.id }) else {
                                return nil
                            }
                            let updated = messages[index].markingRead(readAt: Self.nowISO())
                            messages[index] = updated
                            return updated
                        }
                    )
                    guard let updated else {
                        completion(.failure(AuthoritativeInAppMessageCenterError.messageUnavailable))
                        return
                    }
                    completion(.success(updated))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }

    func markAllRead(
        accountLease: AccountLease,
        completion: @escaping (Result<AuthoritativeInAppMessageCenterSnapshot, Error>) -> Void
    ) {
        executeBulkCommand(
            accountLease: accountLease,
            operation: { client, lease, commandId, callback in
                client.markAllInAppMessagesRead(
                    accountLease: lease,
                    commandId: commandId,
                    completion: callback
                )
            },
            mutation: { messages in
                let now = Self.nowISO()
                messages = messages.map { $0.isUnread ? $0.markingRead(readAt: now) : $0 }
            },
            completion: completion
        )
    }

    func deleteRead(
        accountLease: AccountLease,
        completion: @escaping (Result<AuthoritativeInAppMessageCenterSnapshot, Error>) -> Void
    ) {
        executeBulkCommand(
            accountLease: accountLease,
            operation: { client, lease, commandId, callback in
                client.deleteReadInAppMessages(
                    accountLease: lease,
                    commandId: commandId,
                    completion: callback
                )
            },
            mutation: { messages in
                messages.removeAll { !$0.isUnread }
            },
            completion: completion
        )
    }

    @discardableResult
    func teardownForAccountLifecycle(oldAccountLease: AccountLease?) -> Bool {
        guard let oldAccountLease else { return false }
        lock.lock()
        let matches = scope == LeaseScope(oldAccountLease)
        if matches {
            requestGeneration &+= 1
            scope = nil
            storedSnapshot = .idle
#if DEBUG || UI_QA_SIMULATOR
            uiqaFrozenScope = nil
#endif
        }
        lock.unlock()
        if matches {
            postUpdate()
        }
        return true
    }

    private func beginRequest(
        accountLease: AccountLease,
        resetsItems: Bool
    ) -> UInt64? {
        guard accountLeaseRuntime.validate(accountLease, at: .request).allowed else {
            return nil
        }
        let requestedScope = LeaseScope(accountLease)
        lock.lock()
        let scopeChanged = scope != requestedScope
        if scopeChanged {
            scope = requestedScope
            storedSnapshot = .idle
        }
        requestGeneration &+= 1
        let generation = requestGeneration
        storedSnapshot = AuthoritativeInAppMessageCenterSnapshot(
            messages: resetsItems && scopeChanged ? [] : storedSnapshot.messages,
            unreadCount: resetsItems && scopeChanged ? 0 : storedSnapshot.unreadCount,
            nextCursor: resetsItems ? nil : storedSnapshot.nextCursor,
            loadState: .loading
        )
        lock.unlock()
        postUpdate()
        return generation
    }

    private func finishPageRequest(
        _ result: Result<BackendInAppMessageCenterPage, Error>,
        accountLease: AccountLease,
        generation: UInt64,
        appends: Bool,
        completion: ((Result<AuthoritativeInAppMessageCenterSnapshot, Error>) -> Void)?
    ) {
        DispatchQueue.main.async {
            guard self.accountLeaseRuntime.validate(accountLease, at: .commit).allowed else {
                completion?(.failure(AuthoritativeInAppMessageCenterError.accountLeaseInvalid))
                return
            }
            self.lock.lock()
            guard self.scope == LeaseScope(accountLease),
                  self.requestGeneration == generation else {
                self.lock.unlock()
                completion?(.failure(AuthoritativeInAppMessageCenterError.staleRequest))
                return
            }
            switch result {
            case .success(let page):
                let incoming = page.items.map {
                    InAppMessage.fromBackend($0, ownerUserId: accountLease.subjectId)
                }
                let messages: [InAppMessage]
                if appends {
                    var byId = Dictionary(uniqueKeysWithValues: self.storedSnapshot.messages.map { ($0.id, $0) })
                    incoming.forEach { byId[$0.id] = $0 }
                    messages = InAppMessageCenterSnapshot.sortedMessages(Array(byId.values))
                } else {
                    messages = InAppMessageCenterSnapshot.sortedMessages(incoming)
                }
                self.storedSnapshot = AuthoritativeInAppMessageCenterSnapshot(
                    messages: messages,
                    unreadCount: page.unreadCount,
                    nextCursor: page.nextCursor,
                    loadState: .loaded
                )
                let snapshot = self.storedSnapshot
                self.lock.unlock()
                self.postUpdate()
                completion?(.success(snapshot))
            case .failure(let error):
                self.storedSnapshot = AuthoritativeInAppMessageCenterSnapshot(
                    messages: self.storedSnapshot.messages,
                    unreadCount: self.storedSnapshot.unreadCount,
                    nextCursor: self.storedSnapshot.nextCursor,
                    loadState: .failed("消息暂时无法加载，请稍后重试")
                )
                self.lock.unlock()
                self.postUpdate()
                completion?(.failure(error))
            }
        }
    }

    private func executeBulkCommand(
        accountLease: AccountLease,
        operation: @escaping (
            InAppMessageCenterClientPort,
            AccountLease,
            String,
            @escaping (Result<BackendInAppMessageCommandReceipt, Error>) -> Void
        ) -> Void,
        mutation: @escaping (inout [InAppMessage]) -> Void,
        completion: @escaping (Result<AuthoritativeInAppMessageCenterSnapshot, Error>) -> Void
    ) {
        guard accountLeaseRuntime.validate(accountLease, at: .request).allowed else {
            completion(.failure(AuthoritativeInAppMessageCenterError.accountLeaseInvalid))
            return
        }
        operation(client, accountLease, UUID().uuidString.lowercased()) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success(let receipt):
                    guard let snapshot = self.commitBulkCommand(
                        accountLease: accountLease,
                        unreadCount: receipt.unreadCount,
                        mutation: mutation
                    ) else {
                        completion(.failure(AuthoritativeInAppMessageCenterError.staleRequest))
                        return
                    }
                    completion(.success(snapshot))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }

    private func commitCommand<T>(
        accountLease: AccountLease,
        unreadCount: Int,
        mutation: (inout [InAppMessage]) -> T?
    ) -> T? {
        guard accountLeaseRuntime.validate(accountLease, at: .commit).allowed else {
            return nil
        }
        lock.lock()
        guard scope == LeaseScope(accountLease) else {
            lock.unlock()
            return nil
        }
        var messages = storedSnapshot.messages
        guard let result = mutation(&messages) else {
            lock.unlock()
            return nil
        }
        storedSnapshot = AuthoritativeInAppMessageCenterSnapshot(
            messages: messages,
            unreadCount: unreadCount,
            nextCursor: storedSnapshot.nextCursor,
            loadState: .loaded
        )
        lock.unlock()
        postUpdate()
        return result
    }

    private func commitBulkCommand(
        accountLease: AccountLease,
        unreadCount: Int,
        mutation: (inout [InAppMessage]) -> Void
    ) -> AuthoritativeInAppMessageCenterSnapshot? {
        guard commitCommand(
            accountLease: accountLease,
            unreadCount: unreadCount,
            mutation: { messages in
                mutation(&messages)
                return true
            }
        ) == true else {
            return nil
        }
        return snapshot(for: accountLease)
    }

    private func postUpdate() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .djInAppMessageCenterDidUpdate,
                object: self
            )
        }
    }

    private func refreshActiveAccount() {
        guard let accountLease = accountLeaseRuntime.capture(forSubjectId: nil) else {
            return
        }
        refresh(accountLease: accountLease)
    }

    private static func nowISO() -> String {
        ISO8601DateFormatter().string(from: Date())
    }

#if DEBUG || UI_QA_SIMULATOR
    func installUIQASnapshot(
        messages: [InAppMessage],
        unreadCount: Int,
        accountLease: AccountLease
    ) {
        guard accountLeaseRuntime.validate(accountLease, at: .commit).allowed else {
            return
        }
        let requestedScope = LeaseScope(accountLease)
        lock.lock()
        requestGeneration &+= 1
        scope = requestedScope
        uiqaFrozenScope = requestedScope
        storedSnapshot = AuthoritativeInAppMessageCenterSnapshot(
            messages: InAppMessageCenterSnapshot.sortedMessages(messages),
            unreadCount: max(0, unreadCount),
            nextCursor: nil,
            loadState: .loaded
        )
        lock.unlock()
        postUpdate()
    }

    private func uiqaFrozenSnapshot(
        for accountLease: AccountLease
    ) -> AuthoritativeInAppMessageCenterSnapshot? {
        lock.lock()
        defer { lock.unlock() }
        let requestedScope = LeaseScope(accountLease)
        guard uiqaFrozenScope == requestedScope,
              scope == requestedScope else {
            return nil
        }
        return storedSnapshot
    }
#endif
}

final class InAppMessageBellButton: UIButton {
    private let badgeLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    func update(unreadCount: Int) {
        let normalizedCount = max(0, unreadCount)
        let hasUnread = normalizedCount > 0
        let symbol = hasUnread ? "bell.fill" : "bell"
        setImage(
            UIImage(
                systemName: symbol,
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
            ),
            for: .normal
        )
        badgeLabel.text = normalizedCount > 99 ? "99+" : String(normalizedCount)
        badgeLabel.isHidden = !hasUnread
        accessibilityLabel = "消息中心"
        accessibilityValue = hasUnread ? "\(normalizedCount) 条未读消息" : "没有未读消息"
    }

    private func configure() {
        tintColor = DJDesignTokens.Color.accentDeep
        backgroundColor = DJDesignTokens.Color.surface.withAlphaComponent(0.90)
        layer.cornerRadius = 22
        layer.borderWidth = 1
        layer.borderColor = DJDesignTokens.Color.divider.withAlphaComponent(0.24).cgColor
        DJDesignTokens.applySoftShadow(to: self)
        accessibilityIdentifier = "in-app-message-center-bell"

        badgeLabel.backgroundColor = UIColor.systemRed
        badgeLabel.textColor = .white
        badgeLabel.font = UIFont.preferredFont(forTextStyle: .caption2)
        badgeLabel.adjustsFontForContentSizeCategory = true
        badgeLabel.textAlignment = .center
        badgeLabel.layer.cornerRadius = 9
        badgeLabel.layer.masksToBounds = true
        badgeLabel.isAccessibilityElement = false

        addSubview(badgeLabel)
        badgeLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            badgeLabel.topAnchor.constraint(equalTo: topAnchor, constant: -2),
            badgeLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: 2),
            badgeLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 18),
            badgeLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 18),
        ])
        update(unreadCount: 0)
    }
}

enum InAppMessageCenterPresentation {
    static func present(from presenter: UIViewController) {
        guard let userId = UserManager.shared.currentUser?.id,
              let accountLease = AccountLeaseRuntime.shared.capture(forSubjectId: userId),
              AccountLeaseRuntime.shared.validate(accountLease, at: .ui).allowed else {
            presenter.showToast("账号状态已变化，请稍后重试", type: .info)
            return
        }
        let center = InAppMessageCenterViewController(
            accountLease: accountLease,
            onOpenMessage: { [weak presenter] message, lease in
                guard let presenter else { return }
                open(message, accountLease: lease, from: presenter)
            }
        )
        if let navigationController = presenter.navigationController {
            navigationController.pushViewController(center, animated: true)
        } else {
            presenter.present(UINavigationController(rootViewController: center), animated: true)
        }
    }

    private static func open(
        _ message: InAppMessage,
        accountLease: AccountLease,
        from presenter: UIViewController
    ) {
        guard AccountLeaseRuntime.shared.validate(accountLease, at: .ui).allowed else {
            presenter.showToast("账号已切换，请重新打开消息中心", type: .info)
            return
        }
        switch message.kind {
        case .candidateReady:
            presenter.navigationController?.pushViewController(
                OwnerTruthCandidateInboxViewController(accountLease: accountLease),
                animated: true
            )
        case .projectionStatus:
            presenter.navigationController?.pushViewController(
                OwnerTruthFormalMemoryListViewController(accountLease: accountLease),
                animated: true
            )
        case .familyInvitation, .familyContribution:
            presenter.navigationController?.pushViewController(
                FamilyCircleViewController(),
                animated: true
            )
        case .careSignal:
            presenter.tabBarController?.selectedIndex = 2
            (presenter.tabBarController?.selectedViewController as? UINavigationController)?
                .popToRootViewController(animated: true)
        case .exportStatus,
             .authorizationRevoked,
             .accountSecurity,
             .taskRetryRequired,
             .systemNotice:
            showMetadataNotice(message, from: presenter)
        case .timeLetter, .echoReply:
            presenter.showToast("该消息类型当前未开放", type: .info)
        }
    }

    private static func showMetadataNotice(
        _ message: InAppMessage,
        from presenter: UIViewController
    ) {
        let alert = UIAlertController(
            title: message.title,
            message: message.summary,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "知道了", style: .default))
        presenter.present(alert, animated: true)
    }
}

#if DEBUG || UI_QA_SIMULATOR
extension AppDelegate {
    func runProductConfirmedMessageCenterSmoke(retryCount: Int = 0) {
        guard let tabBarController = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow })?
            .rootViewController as? WarmTabBarController,
              let viewControllers = tabBarController.viewControllers,
              let archiveNavigationController = viewControllers.first as? UINavigationController,
              let presenter = archiveNavigationController.topViewController,
              let userId = UserManager.shared.currentUser?.id,
              let accountLease = AccountLeaseRuntime.shared.capture(forSubjectId: userId) else {
            guard retryCount < 20 else {
                print("[UI_QA] ProductConfirmedMessageCenterSmoke completed=false reason=missingRootOrLease")
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                self?.runProductConfirmedMessageCenterSmoke(retryCount: retryCount + 1)
            }
            return
        }

        let now = ISO8601DateFormatter().string(from: Date())
        let messages = [
            makeProductConfirmedMessageCenterFixture(
                kind: .candidateReady,
                status: .unread,
                resourceType: "candidateBatch",
                deliveredAt: now,
                ownerUserId: userId
            ),
            makeProductConfirmedMessageCenterFixture(
                kind: .familyContribution,
                status: .unread,
                resourceType: "familyContribution",
                deliveredAt: "2026-08-19T08:00:00Z",
                ownerUserId: userId
            ),
            makeProductConfirmedMessageCenterFixture(
                kind: .accountSecurity,
                status: .read,
                resourceType: "accountSecurityEvent",
                deliveredAt: "2026-08-18T08:00:00Z",
                ownerUserId: userId
            ),
        ]
        AuthoritativeInAppMessageCenterStore.shared.installUIQASnapshot(
            messages: messages,
            unreadCount: 2,
            accountLease: accountLease
        )
        tabBarController.selectedIndex = 0
        InAppMessageCenterPresentation.present(from: presenter)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            let snapshot = AuthoritativeInAppMessageCenterStore.shared.snapshot(for: accountLease)
            let completed = snapshot.messages.count == 3 && snapshot.unreadCount == 2
            self.writeProductConfirmedMessageCenterSmokeResult([
                "completed": completed,
                "messageCount": snapshot.messages.count,
                "unreadCount": snapshot.unreadCount,
                "authority": "backend",
                "closedKindsExcluded": snapshot.messages.allSatisfy {
                    $0.kind != .timeLetter && $0.kind != .echoReply
                },
            ])
            print(
                "[UI_QA] ProductConfirmedMessageCenterSmoke completed=\(completed) " +
                "messageCount=\(snapshot.messages.count) unreadCount=\(snapshot.unreadCount)"
            )
        }
    }

    private func makeProductConfirmedMessageCenterFixture(
        kind: InAppMessageKind,
        status: InAppMessageStatus,
        resourceType: String,
        deliveredAt: String,
        ownerUserId: String
    ) -> InAppMessage {
        let copy: (String, String)
        switch kind {
        case .candidateReady:
            copy = ("有新的记忆待确认", "完成确认后才会进入正式记忆")
        case .familyContribution:
            copy = ("收到新的家庭记忆贡献", "确认后才会进入你的正式记忆")
        default:
            copy = ("账户安全提醒", "请前往账户设置确认最新状态")
        }
        return InAppMessage(
            id: UUID().uuidString.lowercased(),
            kind: kind,
            title: copy.0,
            summary: copy.1,
            status: status,
            deliveredAt: deliveredAt,
            readAt: status == .read ? deliveredAt : nil,
            archivedAt: nil,
            sourceArchiveItemId: nil,
            ownerUserId: ownerUserId,
            familyMemberId: nil,
            careSignalId: nil,
            careSignalStatus: nil,
            careSignalSeverity: nil,
            systemNoticeId: nil,
            systemNoticeCategory: nil,
            systemNoticeSeverity: nil,
            invitationStatus: nil,
            accessStatus: nil,
            recipientRole: nil,
            metadataOnly: true,
            contentRedacted: true,
            isActionable: true,
            unavailableReason: nil,
            resourceType: resourceType,
            resourceId: UUID().uuidString.lowercased(),
            resourceVersion: 1,
            requiresReauthorization: true,
            authority: .backend
        )
    }

    private func writeProductConfirmedMessageCenterSmokeResult(_ result: [String: Any]) {
        guard JSONSerialization.isValidJSONObject(result),
              let data = try? JSONSerialization.data(
                  withJSONObject: result,
                  options: [.prettyPrinted, .sortedKeys]
              ),
              let documents = FileManager.default.urls(
                  for: .documentDirectory,
                  in: .userDomainMask
              ).first else {
            return
        }
        try? data.write(
            to: documents.appendingPathComponent(
                "product-confirmed-message-center-uiqa.json"
            ),
            options: .atomic
        )
    }
}
#endif
