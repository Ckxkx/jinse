import json,sys
devices=json.load(open(sys.argv[1]))['devices']
options=[(tuple(map(int,r.split('iOS-')[1].split('-'))),d['name'],d['udid']) for r,ds in devices.items() if 'iOS-' in r for d in ds if d['isAvailable'] and d['name'].startswith('iPhone')]
version,name,udid=max(options)
print('iOS',version,name,udid,file=sys.stderr)
print(udid)
