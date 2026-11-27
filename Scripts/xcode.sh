set -eu
app=$(python3 - <<'PY'
import glob,re
apps=glob.glob('/Applications/Xcode_*.app')
versions=[(tuple(map(int,m.group(1).split('.'))),a) for a in apps if (m:=re.fullmatch(r'/Applications/Xcode_(26(?:\.\d+)*)\.app',a))]
print(max(versions)[1])
PY
)
sudo xcode-select -s "$app/Contents/Developer"
