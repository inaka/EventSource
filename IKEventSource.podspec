
Pod::Spec.new do |s|
  s.name         = "IKEventSource"
  s.version      = "1.1.3"
  s.summary      = "Server-sent events EventSource implementation in Swift."
  s.homepage     = "https://github.com/inaka/EventSource"
  s.screenshots  = "http://giant.gfycat.com/BossyDistantHadrosaurus.gif"
  s.license      = "Apache License Version 2.0"
  s.author             = { "Andres Canal" => "andres@inakanetworks.com" }
  s.social_media_url   = "http://twitter.com/inaka"
  s.ios.deployment_target = '8.0'
  s.osx.deployment_target = '10.10'
  s.source       = { :git => "https://github.com/inaka/EventSource.git", :tag => "1.1.3" }
  s.source_files  = "EventSource", "EventSource/**/*.{h,m}"
end
