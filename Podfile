# 寻梦环游 (DreamJourney) - iOS
platform :ios, '15.0'

# 火山引擎私有 Pod 源
source 'https://github.com/volcengine/volcengine-specs.git'
source 'https://github.com/CocoaPods/Specs.git'

target 'DreamJourney' do
  use_frameworks!

  # ===== 网络层 =====
  pod 'Alamofire', '~> 5.9'
  pod 'Moya', '~> 15.0'

  # ===== UI / 自动布局 =====
  pod 'SnapKit', '~> 5.7'
  pod 'Kingfisher', '~> 7.10'
  pod 'MJRefresh', '~> 3.7'
  pod 'IQKeyboardManagerSwift', '~> 7.0'

  # ===== 数据持久化 =====
  pod 'KeychainAccess', '~> 4.2'

  # ===== 地图 =====
  pod 'AMapFoundation'
  pod 'AMap3DMap'

  # ===== 语音对话 SDK =====
  pod 'SpeechEngineToB', '0.0.14.6.1-bugfix'

  # ===== 工具 =====
  pod 'SwiftyJSON', '~> 5.0'
  pod 'CocoaLumberjack/Swift', '~> 3.8'

  # ===== 调试（仅 Debug） =====
  pod 'SwiftLint', '~> 0.55', :configurations => ['Debug']
end

post_install do |installer|
  # 确保主工程和所有 Pod 都支持模拟器
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
      config.build_settings['ENABLE_BITCODE'] = 'NO'
    end
  end
  # 修复主工程不支持模拟器的问题
  installer.aggregate_targets.each do |aggregate_target|
    aggregate_target.user_project.targets.each do |target|
      target.build_configurations.each do |config|
        config.build_settings['SUPPORTED_PLATFORMS'] ||= 'iphoneos iphonesimulator'
      end
    end
    aggregate_target.user_project.save
  end
  # AMap SDK 头文件搜索路径
  installer.pods_project.targets.each do |target|
    if target.name == 'AMapFoundation' || target.name == 'AMap3DMap'
      target.build_configurations.each do |config|
        config.build_settings['FRAMEWORK_SEARCH_PATHS'] ||= ['$(inherited)']
        config.build_settings['FRAMEWORK_SEARCH_PATHS'] << '$(PODS_ROOT)/AMapFoundation'
        config.build_settings['FRAMEWORK_SEARCH_PATHS'] << '$(PODS_ROOT)/AMap3DMap'
      end
    end
  end

  # UI QA on Simulator: SpeechEngineToB and AMap ship device-only binaries in
  # the current Pod set. The app uses UI_QA_SIMULATOR stubs for those surfaces,
  # so simulator linking must omit their device-only libraries/frameworks.
  simulator_ldflags = 'OTHER_LDFLAGS[sdk=iphonesimulator*] = -ObjC -l"c++" -l"icucore" -l"swiftCoreGraphics" -l"z" -framework "AVFoundation" -framework "Accelerate" -framework "Alamofire" -framework "AudioToolbox" -framework "CFNetwork" -framework "CocoaLumberjack" -framework "Combine" -framework "CoreGraphics" -framework "CoreLocation" -framework "CoreTelephony" -framework "CoreText" -framework "Foundation" -framework "GLKit" -framework "IQKeyboardCore" -framework "IQKeyboardManagerSwift" -framework "IQKeyboardNotification" -framework "IQTextInputViewNotification" -framework "JavaScriptCore" -framework "KeychainAccess" -framework "Kingfisher" -framework "MJRefresh" -framework "MetalPerformanceShaders" -framework "Moya" -framework "OpenGLES" -framework "QuartzCore" -framework "Security" -framework "SnapKit" -framework "SocketRocket" -framework "SwiftyJSON" -framework "SystemConfiguration" -framework "UIKit" -weak_framework "Combine" -weak_framework "SwiftUI"'
  simulator_library_paths = 'LIBRARY_SEARCH_PATHS[sdk=iphonesimulator*] = "${TOOLCHAIN_DIR}/usr/lib/swift/${PLATFORM_NAME}" /usr/lib/swift $(SDKROOT)/usr/lib/swift'
  simulator_swift_conditions = 'SWIFT_ACTIVE_COMPILATION_CONDITIONS[sdk=iphonesimulator*] = $(inherited) UI_QA_SIMULATOR'

  ['debug', 'release'].each do |configuration|
    xcconfig_path = File.join(
      __dir__,
      'Pods',
      'Target Support Files',
      'Pods-DreamJourney',
      "Pods-DreamJourney.#{configuration}.xcconfig"
    )
    next unless File.exist?(xcconfig_path)

    lines = File.readlines(xcconfig_path, chomp: true)
    lines.reject! do |line|
      line.start_with?('OTHER_LDFLAGS[sdk=iphonesimulator*]') ||
        line.start_with?('LIBRARY_SEARCH_PATHS[sdk=iphonesimulator*]') ||
        line.start_with?('SWIFT_ACTIVE_COMPILATION_CONDITIONS[sdk=iphonesimulator*]')
    end

    insert_at = lines.index { |line| line.start_with?('OTHER_LDFLAGS =') } || lines.length - 1
    lines.insert(insert_at + 1, simulator_library_paths, simulator_ldflags, simulator_swift_conditions)
    File.write(xcconfig_path, "#{lines.join("\n")}\n")
  end
end
