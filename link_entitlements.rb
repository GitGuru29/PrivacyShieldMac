require 'xcodeproj'

project_path = 'PrivacyShield.xcodeproj'
project = Xcodeproj::Project.open(project_path)

target = project.targets.find { |t| t.name == 'PrivacyShield' }

if target.nil?
    puts "Error: Target 'PrivacyShield' not found."
    exit 1
end

# Add the entitlements file to the project's build settings so Xcode uses it
target.build_configurations.each do |config|
    config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'PrivacyShield/PrivacyShield.entitlements'
end

project.save
puts "Successfully linked PrivacyShield.entitlements to build settings!"
