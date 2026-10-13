param(
    [string]$AndroidSdk = "$env:LOCALAPPDATA\Android\Sdk",
    [string]$JavaSdk = 'C:\Program Files\Android\Android Studio1\jbr'
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path -LiteralPath (Join-Path $AndroidSdk 'platform-tools\adb.exe'))) { throw 'Android SDK platform-tools not found.' }
if (-not (Test-Path -LiteralPath (Join-Path $JavaSdk 'bin\keytool.exe'))) { throw 'Java SDK keytool not found. Pass -JavaSdk with a JDK 17+ path.' }
$debugKey = Join-Path $projectRoot '.tools\debug.keystore'
if (-not (Test-Path -LiteralPath $debugKey)) {
    & (Join-Path $JavaSdk 'bin\keytool.exe') -genkeypair -keystore $debugKey -storepass android -keypass android -alias androiddebugkey -dname 'CN=Android Debug,O=Android,C=US' -keyalg RSA -validity 10000
    if ($LASTEXITCODE -ne 0) { throw 'Debug keystore generation failed.' }
}
$editorData = Join-Path $projectRoot '.tools\godot\editor_data'
New-Item -ItemType Directory -Path $editorData -Force | Out-Null
$sdkNormalized = $AndroidSdk.Replace('\','/')
$jdkNormalized = $JavaSdk.Replace('\','/')
$keyNormalized = $debugKey.Replace('\','/')
$settings = @"
[gd_resource type="EditorSettings" format=3]

[resource]
export/android/android_sdk_path = "$sdkNormalized"
export/android/java_sdk_path = "$jdkNormalized"
export/android/debug_keystore = "$keyNormalized"
export/android/debug_keystore_user = "androiddebugkey"
export/android/debug_keystore_pass = "android"
"@
Set-Content -LiteralPath (Join-Path $editorData 'editor_settings-4.6.tres') -Value $settings -Encoding utf8
Write-Output 'Android SDK/JDK paths configured in project-local portable editor settings.'
