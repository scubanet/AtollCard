import Foundation
import Supabase

protocol WalletPassProviding {
    func passData(forCardId id: UUID) async throws -> Data
}

struct SupabaseWalletService: WalletPassProviding {
    let client: SupabaseClient
    init(client: SupabaseClient = AtollSupabase.client) { self.client = client }

    func passData(forCardId id: UUID) async throws -> Data {
        // supabase-swift 2.48 has no raw-`Data` overload of `invoke`; the
        // `Decodable` overload would JSON-decode the body (wrong for raw
        // `.pkpass` bytes). Use the `decode:` closure overload to return the
        // raw response bytes verbatim.
        try await client.functions.invoke(
            "generate-pass",
            options: FunctionInvokeOptions(body: ["cardId": id.uuidString])
        ) { data, _ in data }
    }
}

@MainActor
final class WalletAddViewModel: ObservableObject {
    @Published var passData: Data?
    @Published var errorMessage: String?
    private let service: WalletPassProviding
    init(service: WalletPassProviding) { self.service = service }

    func fetch(cardId: UUID) async {
        do {
            passData = try await service.passData(forCardId: cardId)
            errorMessage = nil
        } catch {
            passData = nil
            errorMessage = error.localizedDescription
        }
    }
}
