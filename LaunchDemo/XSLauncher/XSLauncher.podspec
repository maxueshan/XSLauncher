Pod::Spec.new do |s|
  s.ios.deployment_target = "11.0"
  s.name             = 'XSLauncher'
  s.version          = '1.0.0'
  s.summary          = 'XSLauncher'
  s.description      = 'launch task schedule'
  s.homepage         = 'https://www.baidu.com'
  s.source           = { :git => '' } 
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'XS' => 'xs@qq.com'}
  s.source_files = ['Source/*.{swift}', 'Source/**/*.{swift}']
  s.pod_target_xcconfig = { 'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) GPB_USE_PROTOBUF_FRAMEWORK_IMPORTS=1' }


end

