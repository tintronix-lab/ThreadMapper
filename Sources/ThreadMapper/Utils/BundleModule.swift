import Foundation

// Xcode 26 generates GeneratedAssetSymbols.swift for SPM targets that uses
// Bundle.module, but does not generate the SPM resource bundle accessor.
// This provides Bundle.module manually so the generated file compiles.
#if SWIFT_PACKAGE
private final class _ThreadMapperBundleToken {}
extension Bundle {
    static let module: Bundle = Bundle(for: _ThreadMapperBundleToken.self)
}
#endif
