#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint posted_sdk.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'posted_sdk'
  s.version          = '1.0.2'
  s.summary          = 'Flutter bridge for the Posted native SDKs.'
  s.description      = <<-DESC
Flutter plugin that reports app installs to Posted through the native PostedSDK.
                       DESC
  s.homepage         = 'https://github.com/thepostedapp/posted-sdk-flutter'
  s.license          = { :type => 'MIT', :file => '../LICENSE' }
  s.author           = { 'Posted' => 'yuriy@postedapp.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*.swift'
  s.dependency 'Flutter'
  s.dependency 'PostedSDK', '~> 1.0.2'
  s.platform = :ios, '13.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.5'
  s.resource_bundles = {'posted_sdk_privacy' => ['Resources/PrivacyInfo.xcprivacy']}
end
