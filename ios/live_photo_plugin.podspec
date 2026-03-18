#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint live_photo_plugin.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'live_photo_plugin'
  s.version          = '0.0.1'
  s.summary          = 'Save mp4 as Live Photo on iOS.'
  s.description      = <<-DESC
A Flutter plugin that converts and saves a video as Live Photo on iOS.
                       DESC
  s.homepage = 'https://github.com/villain535/live_photo_plugin'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Name' => 'you@example.com' }
  s.source           = { :path => '.' }

  s.source_files         = 'Classes/**/*'
  s.public_header_files  = 'Classes/**/*.h'
  s.resources            = ['Assets/metadata.mov']

  s.dependency 'Flutter'
  s.platform = :ios, '13.0'
  s.swift_version = '5.0'

  s.frameworks = 'Photos', 'AVFoundation', 'UIKit', 'ImageIO', 'MobileCoreServices'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386'
  }

  s.resource_bundles = {
    'live_photo_plugin_privacy' => ['Resources/PrivacyInfo.xcprivacy']
  }
end