import Foundation
import MihonCore

// The JavaScriptCore source runtime (ADR-1). JavaScriptCore is Apple-only, so
// the entire module body is guarded: on Windows/Linux this compiles to an empty
// module and the package still builds, keeping `swift test` green everywhere.
// The real implementation only ever builds on the macOS CI runner.
#if canImport(JavaScriptCore)
import JavaScriptCore

/// Runs a JavaScript source (ADR-1 recommendation, pending ADR-0/ADR-1 sign-off)
/// inside a `JSContext`, conforming to the platform-agnostic `Source` protocol.
///
/// Design constraints already surfaced by the analysis — bake these in from the
/// start, they are v1 requirements, not hardening:
///   - Nested `eval()` of SITE-supplied JS must run in a SECOND, bridge-free
///     `JSContext` with a hard timeout (plan R2). Never eval remote strings in
///     the context that holds the host bridge.
///   - The host-function surface (HTTP, cookie jar, storage, image transforms)
///     must be minimal, enumerable, and documented as an App-Review artifact
///     (Guideline 4.7.2).
///   - A Cheerio-equivalent DOM layer must reproduce Jsoup SELECTOR SEMANTICS,
///     not just CSS (plan R1): `:matches()` is regex in Jsoup, `absUrl` needs a
///     host-provided base-URI resolver, etc.
public final class JSCSource: @unchecked Sendable {
    // TODO(port): implement against the Source protocol. Placeholder so the
    // module has a symbol and the boundary is real.
    public init() {}
}

#endif
