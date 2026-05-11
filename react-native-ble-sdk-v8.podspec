require "json"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))

Pod::Spec.new do |s|
  s.name         = "react-native-ble-sdk-v8"
  s.version      = package["version"]
  s.summary      = package["description"]
  s.homepage     = "https://github.com/your-org/react-native-ble-sdk-v8"
  s.license      = "MIT"
  s.authors      = { "Your Name" => "you@example.com" }

  s.platforms    = { :ios => "11.0" }
  s.source       = { :git => "https://github.com/your-org/react-native-ble-sdk-v8.git", :tag => "#{s.version}" }

  s.source_files = "ios/**/*.{h,m}"

  # Pre-compiled BleSDK static library
  s.vendored_libraries = "ios/BleSDK/libBleSDK.a"

  # Expose SDK headers
  s.preserve_paths = "ios/BleSDK/*.h"
  s.xcconfig = {
    "HEADER_SEARCH_PATHS" => "$(PODS_ROOT)/../node_modules/react-native-ble-sdk-v8/ios/BleSDK"
  }

  s.frameworks   = "CoreBluetooth", "Foundation"

  s.dependency "React-Core"
end
