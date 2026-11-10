import Foundation
import Supabase

enum SupabaseService {
    static let client = SupabaseClient(
        supabaseURL: URL(string: Secrets.supabaseURL)!,
        supabaseKey: Secrets.supabasePublishableKey,
        options: SupabaseClientOptions(
            auth: .init(emitLocalSessionAsInitialSession: true)
        )
    )
}
