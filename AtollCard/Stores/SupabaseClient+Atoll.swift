import Foundation
import Supabase

enum AtollSupabase {
    // Defaults to the hosted project; override via env for local dev.
    // The anon/publishable key is safe to ship (it is gated by RLS).
    static let url = URL(string: ProcessInfo.processInfo.environment["SUPABASE_URL"]
        ?? "https://bhkeplfkuismwyfiqcga.supabase.co")!
    static let anonKey = ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"]
        ?? "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJoa2VwbGZrdWlzbXd5ZmlxY2dhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI2NjA2MTAsImV4cCI6MjA5ODIzNjYxMH0.SzH-0Cz_PWIOuESMI4IFz8Bq4Fs2oW4AtTadPehwPYs"

    static let client = SupabaseClient(
        supabaseURL: url,
        supabaseKey: anonKey,
        options: SupabaseClientOptions(
            auth: SupabaseClientOptions.AuthOptions(
                emitLocalSessionAsInitialSession: true
            )
        )
    )
}
