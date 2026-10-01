#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint app_limiter.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'app_limiter'
  s.version          = '0.1.0'
  s.summary          = 'Limit screen time or block apps on Android and iOS.'
  s.description      = <<-DESC
Flutter plugin that blocks apps using the Screen Time API (FamilyControls / ManagedSettings) on iOS.
                       DESC
  s.homepage         = 'https://github.com/connect-rizwan/AppLimiter-Plugin-Flutetr'
  s.license          = { :file => '../LICENSE' }
  s.author           = 'Rizwan Ali'
  s.source           = { :path => '.' }
  s.source_files = 'app_limiter/Sources/app_limiter/**/*.swift'
  s.dependency 'Flutter'
  s.platform = :ios, '15.0'
  s.frameworks = 'FamilyControls', 'ManagedSettings', 'DeviceActivity', 'SwiftUI'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  s.resource_bundles = {'app_limiter_privacy' => ['app_limiter/Sources/app_limiter/PrivacyInfo.xcprivacy']}
end
