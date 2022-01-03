Pod::Spec.new do |spec|

  spec.name         = "PLAudioMixer"
  spec.version      = "1.0"
  spec.summary      = "A CocoaPods library written in Swift"

  spec.description  = <<-DESC
This CocoaPods library helps you perform calculation.
                   DESC

  spec.homepage     = "https://github.com/GitHub-Ram/AudioBuffer"
  spec.license      = { :type => "MIT", :file => "LICENSE" }
  spec.author       = { "ram" => "rk9629304097@gmail.com" }

  spec.ios.deployment_target = "11.0"
  spec.swift_version = "5.0"

  spec.source        = { :git => "https://github.com/GitHub-Ram/AudioBuffer.git", :tag => "#{spec.version}" }
  spec.source_files  = "PLAudioMixer/*.{h,m,swift}"

end