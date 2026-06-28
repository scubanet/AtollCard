import Foundation
import Supabase

enum AtollSupabase {
    // Local dev values; production values injected via xcconfig in M4.
    static let url = URL(string: ProcessInfo.processInfo.environment["SUPABASE_URL"]
        ?? "http://127.0.0.1:54321")!
    static let anonKey = ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"] ?? "REPLACE_WITH_LOCAL_ANON_KEY"

    static let client = SupabaseClient(supabaseURL: url, supabaseKey: anonKey)
}
