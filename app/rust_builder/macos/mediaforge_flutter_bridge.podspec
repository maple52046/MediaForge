Pod::Spec.new do |s|
  s.name             = 'mediaforge_flutter_bridge'
  s.version          = '0.2.0'
  s.summary          = 'Native Rust bridge for MediaForge.'
  s.description      = <<-DESC
Builds and links the MediaForge Rust bridge through Cargokit.
                       DESC
  s.homepage         = 'https://github.com/maple52046/MediaForge'
  s.license          = { :type => 'MIT', :file => '../../../LICENSE' }
  s.author           = { 'MediaForge Contributors' => 'opensource@mediaforge.app' }

  s.source           = { :git => 'https://github.com/maple52046/MediaForge.git', :tag => "v#{s.version}" }
  s.source_files     = 'Classes/**/*'
  s.dependency 'FlutterMacOS'

  s.platform = :osx, '13.0'
  s.swift_version = '5.0'

  s.script_phase = {
    :name => 'Build Rust library',
    :script => 'sh "$PODS_TARGET_SRCROOT/../cargokit/build_pod.sh" ../../../crates/mediaforge-flutter-bridge mediaforge_flutter_bridge',
    :execution_position => :before_compile,
    :input_files => ['${BUILT_PRODUCTS_DIR}/cargokit_phony'],
    :output_files => ["${BUILT_PRODUCTS_DIR}/libmediaforge_flutter_bridge.a"],
  }
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'OTHER_LDFLAGS' => '-force_load ${BUILT_PRODUCTS_DIR}/libmediaforge_flutter_bridge.a',
  }
end
