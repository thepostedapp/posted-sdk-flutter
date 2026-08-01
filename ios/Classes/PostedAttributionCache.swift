import Foundation

/// Persistence for the fire-once attribution result cached after the first
/// successful `resolveAppLaunch`.
///
/// Two defensive invariants (mirrors the iOS SDK hardening in POS-140):
///
///   1. **Flag last.** The blob and schema version are written *before* the
///      resolved flag. A crash/interruption mid-write therefore never leaves
///      the flag set without a decodable blob — the cache stays invalid and
///      the launch re-resolves instead of short-circuiting to empty data.
///   2. **Versioned.** Each cached blob is stamped with `version`. On read the
///      cache is only honored when the stored version matches the current one;
///      a legacy (unversioned) or incompatible blob is dropped and re-resolved
///      rather than decoded into stale/garbage data.
enum PostedAttributionCache {
    /// Bump this whenever the stored key layout changes in a way that older
    /// blobs cannot be decoded into safely.
    static let version = 1

    static let keyResolved = "posted_sdk_attributionResolved"
    static let keyVersion = "posted_sdk_attributionCacheVersion"
    static let keyHasLink = "posted_sdk_attributionHasLink"
    static let keyUrl = "posted_sdk_attributionLinkUrl"
    static let keyRoute = "posted_sdk_attributionLinkRoute"
    static let keyPathname = "posted_sdk_attributionLinkPathname"
    static let keyType = "posted_sdk_attributionLinkType"
    static let keyParams = "posted_sdk_attributionLinkParams"

    static let allKeys = [
        keyResolved, keyVersion, keyHasLink,
        keyUrl, keyRoute, keyPathname, keyType, keyParams,
    ]

    /// Debug/test-only observability: incremented each time `save` fails to
    /// JSON-encode `params`. The rest of the link blob and the resolved flag
    /// are still persisted (params degrade to an empty map on load) rather
    /// than dropping the whole cache — params that fail to encode once will
    /// fail identically on every future launch, so invalidating the cache
    /// would turn a one-off encoding gap into a permanent re-resolve loop.
    /// Not part of the public SDK contract.
    static var debugParamsEncodeFailureCount = 0

    /// `true` only when a fully-persisted, version-matched result is cached.
    /// A set flag without a matching version (partial write or legacy cache)
    /// reports `false` so the caller re-resolves.
    static func hasValidResolvedCache(_ defaults: UserDefaults) -> Bool {
        guard defaults.bool(forKey: keyResolved) else { return false }
        return defaults.integer(forKey: keyVersion) == version
    }

    /// Persists the resolved result. Writes the blob and schema version first
    /// and sets the resolved flag *last*, so an interrupted write never leaves
    /// the flag set without a decodable blob.
    static func save(_ map: [String: Any?], to defaults: UserDefaults) {
        if let link = map["link"] as? [String: Any] {
            defaults.set(true, forKey: keyHasLink)
            defaults.set(link["url"] as? String ?? "", forKey: keyUrl)
            defaults.set(link["route"] as? String ?? "", forKey: keyRoute)
            defaults.set(link["pathname"] as? String ?? "", forKey: keyPathname)
            defaults.set(link["type"] as? String ?? "", forKey: keyType)
            if let params = link["params"] as? [String: Any],
               let paramsData = try? JSONSerialization.data(withJSONObject: params) {
                defaults.set(paramsData, forKey: keyParams)
            } else {
                defaults.removeObject(forKey: keyParams)
                if link["params"] != nil {
                    debugParamsEncodeFailureCount += 1
                    #if DEBUG
                    print("posted-sdk: attribution cache params failed to JSON-encode; degrading to empty params.")
                    #endif
                }
            }
        } else {
            defaults.set(false, forKey: keyHasLink)
            defaults.removeObject(forKey: keyParams)
        }
        defaults.set(version, forKey: keyVersion)
        // Flag written LAST: any failure before this point leaves the cache
        // invalid (flag unset) rather than flag-without-blob.
        defaults.set(true, forKey: keyResolved)
        defaults.synchronize()
    }

    /// Reads a previously-persisted result. Callers must gate on
    /// `hasValidResolvedCache` first.
    static func load(from defaults: UserDefaults) -> [String: Any?] {
        let hasLink = defaults.bool(forKey: keyHasLink)
        guard hasLink else { return ["processed": true, "link": nil] }

        var params: [String: Any] = [:]
        if let paramsData = defaults.data(forKey: keyParams),
           let parsed = try? JSONSerialization.jsonObject(with: paramsData) as? [String: Any] {
            params = parsed
        }
        return [
            "processed": true,
            "link": [
                "url": defaults.string(forKey: keyUrl) ?? "",
                "route": defaults.string(forKey: keyRoute) ?? "",
                "pathname": defaults.string(forKey: keyPathname) ?? "",
                "type": defaults.string(forKey: keyType) ?? "",
                "params": params,
            ] as [String: Any],
        ]
    }

    /// Drops every cached attribution key (used on reset and on version drop).
    static func clear(_ defaults: UserDefaults) {
        for key in allKeys {
            defaults.removeObject(forKey: key)
        }
    }
}
