import Foundation
import Observation
import StoreKit

@MainActor
@Observable
final class ProStore {
    static let shared = ProStore()

    static let annualID   = "com.tintronixlab.ThreadMapper.pro.annual"
    static let lifetimeID = "com.tintronixlab.ThreadMapper.pro.lifetime"

    private(set) var isPro: Bool = false
    private(set) var products: [Product] = []
    private(set) var purchaseInProgress = false

    @ObservationIgnored private var updateTask: Task<Void, Never>?

    private init() {
        // Fast path: use persisted value so UI doesn't flicker while StoreKit verifies
        isPro = UserDefaults.standard.bool(forKey: "isPro")
        #if DEBUG
        isPro = true   // always Pro in debug builds so features are accessible during development
        #endif
        updateTask = Task {
            await verifyEntitlements()
            await observeTransactions()
        }
    }

    func loadProducts() async {
        guard products.isEmpty else { return }
        products = (try? await Product.products(for: [Self.annualID, Self.lifetimeID])) ?? []
    }

    func purchase(_ product: Product) async throws {
        purchaseInProgress = true
        defer { purchaseInProgress = false }
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try verification.payloadValue
            await transaction.finish()
            setPro(true)
        case .userCancelled:
            break
        default:
            break
        }
    }

    func restore() async {
        try? await AppStore.sync()
        await verifyEntitlements()
    }

    private func verifyEntitlements() async {
        var hasPro = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let tx) = result,
               tx.productID == Self.annualID || tx.productID == Self.lifetimeID,
               tx.revocationDate == nil {
                hasPro = true
            }
        }
        #if !DEBUG
        setPro(hasPro)
        #endif
    }

    private func observeTransactions() async {
        for await result in Transaction.updates {
            if case .verified(let tx) = result {
                await tx.finish()
                await verifyEntitlements()
            }
        }
    }

    private func setPro(_ value: Bool) {
        isPro = value
        UserDefaults.standard.set(value, forKey: "isPro")
        UserDefaults(suiteName: AppGroupStore.groupID)?.set(value, forKey: "isPro")
    }
}
