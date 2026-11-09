import sys

for app in ["rider", "driver", "admin"]:
    filepath = f"{app}/android/app/build.gradle.kts"
    with open(filepath, 'r') as f:
        content = f.read()
    
    signing_config_str = """
    signingConfigs {
        create("release") {
            storeFile = file("upload-keystore.jks")
            storePassword = "localauto123"
            keyAlias = "upload"
            keyPassword = "localauto123"
        }
    }
    
    buildTypes {"""
    
    # Insert signingConfigs before buildTypes
    content = content.replace("    buildTypes {", signing_config_str)
    
    # Change signingConfig in release
    content = content.replace('signingConfig = signingConfigs.getByName("debug")', 'signingConfig = signingConfigs.getByName("release")')
    
    with open(filepath, 'w') as f:
        f.write(content)
        
print("Updated all build.gradle.kts files")
