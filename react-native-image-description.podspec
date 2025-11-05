require "json"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))

Pod::Spec.new do |s|
  s.name         = "react-native-image-description"
  s.version      = package["version"]
  s.summary      = package["description"]
  s.homepage     = package["homepage"]
  s.license      = package["license"]
  s.authors      = package["author"]

  s.platforms    = { :ios => "17.0" }
  s.source       = { :git => "https://github.com/dariyd/react-native-image-description.git", :tag => "#{s.version}" }

  s.source_files = "ios/**/*.{h,m,mm,swift}"

  s.dependency "React-Core"
  s.frameworks = "Vision", "CoreML", "UIKit"
  
  # ML Kit for iOS - Image Labeling (per docs)
  s.dependency "GoogleMLKit/ImageLabeling", "9.0.0"
  
  # Enable modules for ML Kit framework imports to work in ObjC++
  s.pod_target_xcconfig = {
    'CLANG_ENABLE_MODULES' => 'YES',
    'OTHER_CFLAGS' => '$(inherited) -fmodules -fcxx-modules'
  }

  # Install dependencies for both old and new architecture
  install_modules_dependencies(s)
end

