import Foundation
import Supabase

enum ProfileNameUpdater {
    /// Best-effort: writes display_name after first login (Apple sends fullName only once).
    static func update(displayName: String, userId: UUID,
                       client: SupabaseClient = AtollSupabase.client) async {
        let trimmed = displayName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        do {
            try await client.from("profiles")
                .update(["display_name": trimmed])
                .eq("id", value: userId.uuidString)
                .execute()
        } catch {
            // best effort — onboarding asks for the card name anyway
        }
    }
}
