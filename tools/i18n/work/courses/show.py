import json,sys
S='/private/tmp/claude-501/-Users-thierry-Developer-ChessLab/2a6557f2-e7e3-4ddf-b165-9d6de1b4cecf/scratchpad/crs/'
last=None
for l in open(S+'src-%s.json'%sys.argv[1]):
    l=l.strip().rstrip(',')
    if l.startswith('{'):
        r=json.loads(l)
        if r['c']!=last: print('##',r['c']); last=r['c']
        print(r['id'],'|',r['en'])
