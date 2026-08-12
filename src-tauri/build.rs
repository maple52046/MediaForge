//! Configures the `Tauri` bundle and its macOS runtime-library search path.

fn main() {
    #[cfg(target_os = "macos")]
    println!("cargo:rustc-link-arg=-Wl,-rpath,@executable_path/../Frameworks");
    tauri_build::build();
}
