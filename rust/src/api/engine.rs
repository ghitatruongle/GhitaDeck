//! Rust engine entry for v2.0.5-demo — proves the Dart<->Rust bridge and
//! reports crate identity to the Dart facade (shown in Settings).

/// Trivial first call across the bridge: reports the core crate version.
pub fn hello_zip() -> String {
    format!("ghita_core {}", env!("CARGO_PKG_VERSION"))
}
