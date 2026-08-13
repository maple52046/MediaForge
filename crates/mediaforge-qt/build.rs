//! Builds the CXX-Qt bridge and embeds the QML application module.

use cxx_qt_build::{CxxQtBuilder, QmlModule};

fn main() {
    let module = QmlModule::new("app.mediaforge.desktop").version(1, 0);

    CxxQtBuilder::new_qml_module(module)
        .file("src/controller.rs")
        .qrc("resources.qrc")
        .qt_module("Network")
        .qt_module("Quick")
        .qt_module("QuickControls2")
        .build();

    #[cfg(target_os = "macos")]
    println!("cargo:rustc-link-arg=-Wl,-rpath,@executable_path/../Frameworks");
}
