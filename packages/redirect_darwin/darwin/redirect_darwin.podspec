Pod::Spec.new do |s|
  s.name             = 'redirect_darwin'
  s.version          = '0.1.0'
  s.summary          = 'Shared iOS and macOS implementation of the redirect plugin'
  s.description      = <<-DESC
Shared iOS and macOS implementation of the redirect plugin using ASWebAuthenticationSession.
                       DESC
  s.homepage         = 'https://github.com/Bdaya-Dev/redirect'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Bdaya Dev' => 'dev@bdaya.dev' }
  s.source           = { :path => '.' }
  s.source_files     = 'redirect_darwin/Sources/redirect_darwin/**/*.swift'

  s.ios.dependency 'Flutter'
  s.osx.dependency 'FlutterMacOS'
  
  s.ios.deployment_target = '13.0'
  s.osx.deployment_target = '10.15'
  
  s.ios.framework = 'AuthenticationServices'
  s.osx.framework = 'AuthenticationServices'
  
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.9'
end
