set -euo pipefail
umask 077
dir="$RUNNER_TEMP/journal-sign"
mkdir -p "$dir"
kc="$RUNNER_TEMP/journal.keychain-db"
pw=$(openssl rand -hex 24)
security create-keychain -p "$pw" "$kc"
security set-keychain-settings -lut 21600 "$kc"
security unlock-keychain -p "$pw" "$kc"
security list-keychains -d user -s "$kc" "$HOME/Library/Keychains/login.keychain-db"
printf '%s' "$DIST_P12" | base64 -D > "$dir/cert.p12"
security import "$dir/cert.p12" -k "$kc" -P "$P12_PASSWORD" -T /usr/bin/codesign
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$pw" "$kc" >/dev/null
printf '%s' "$APP_PROFILE" | base64 -D > "$dir/profile"
security cms -D -i "$dir/profile" > "$dir/profile.plist"
uuid=$(python3 - "$dir" <<'PY'
import os,sys,plistlib,pathlib
p=pathlib.Path(sys.argv[1])
profile=plistlib.loads((p/'profile.plist').read_bytes())
bundle,team=os.environ['BUNDLE_ID'],os.environ['TEAM_ID']
ent=profile['Entitlements']
assert team in profile['TeamIdentifier'] and ent['application-identifier'].split('.',1)[1]==bundle, 'Bundle ID 或 Team ID 不匹配'
assert not profile.get('ProvisionedDevices') and not profile.get('ProvisionsAllDevices') and not ent.get('get-task-allow'), '需要 App Store Connect 分发描述文件'
uuid=profile['UUID']
(p/'export.plist').write_bytes(plistlib.dumps(dict(method='app-store-connect',teamID=team,signingStyle='manual',signingCertificate='Apple Distribution',provisioningProfiles={bundle:uuid},manageAppVersionAndBuildNumber=False)))
print(uuid)
PY
)
profiles="$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles"
mkdir -p "$profiles"
echo "$profiles/$uuid.mobileprovision" > "$RUNNER_TEMP/journal-profile-path"
cp "$dir/profile" "$profiles/$uuid.mobileprovision"
build=$(python3 - <<'PY'
import time
days,seconds=divmod(int(time.time())-1735689600,86400)
slot=seconds//10
print(f'{days}.{slot//100}.{slot%100}')
PY
)
echo "发布构建号 $build"
xcodebuild archive -project Timeline.xcodeproj -scheme Timeline -configuration Release -destination generic/platform=iOS -archivePath "$dir/Timeline.xcarchive" PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID" DEVELOPMENT_TEAM="$TEAM_ID" CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="Apple Distribution" PROVISIONING_PROFILE_SPECIFIER="$uuid" CURRENT_PROJECT_VERSION="$build"
xcodebuild -exportArchive -archivePath "$dir/Timeline.xcarchive" -exportPath output -exportOptionsPlist "$dir/export.plist"
