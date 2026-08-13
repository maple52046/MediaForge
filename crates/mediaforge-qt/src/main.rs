//! Qt composition root for the `MediaForge` desktop application.

mod controller;

use cxx_qt::casting::Upcast;
use cxx_qt_lib::{QGuiApplication, QQmlApplicationEngine, QQmlEngine, QUrl};
use tracing_subscriber::EnvFilter;

fn main() {
    tracing_subscriber::fmt()
        .with_env_filter(EnvFilter::from_default_env())
        .json()
        .init();

    let mut application = QGuiApplication::new();
    let mut engine = QQmlApplicationEngine::new();
    if let Some(engine) = engine.as_mut() {
        engine.load(&QUrl::from("qrc:/mediaforge/qml/Main.qml"));
    }
    if let Some(engine) = engine.as_mut() {
        let engine: std::pin::Pin<&mut QQmlEngine> = engine.upcast_pin();
        engine
            .on_quit(|_| tracing::debug!("QML engine requested application quit"))
            .release();
    }
    if let Some(application) = application.as_mut() {
        application.exec();
    }
}
