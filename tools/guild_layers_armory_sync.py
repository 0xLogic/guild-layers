"""Fetch public character snapshots and generate a data-only addon cache. Reload UI to load it."""
import argparse,json,re,time,urllib.request,urllib.parse,os
from pathlib import Path

def lua(value):
 if value is None:return 'nil'
 if isinstance(value,bool):return 'true' if value else 'false'
 if isinstance(value,(int,float)):
  if not -1e15<=value<=1e15:raise ValueError('Invalid numeric value')
  return str(value)
 if isinstance(value,str):return '"'+''.join('\\%03d'%b for b in value.encode('utf-8'))+'"'
 if isinstance(value,list):return '{'+','.join(lua(v) for v in value)+'}'
 if isinstance(value,dict):return '{'+','.join('['+lua(k)+']='+lua(v) for k,v in value.items())+'}'
 raise ValueError('Unsupported data type')

def profile(data,slug):
 details=data.get('details',{});p=(details.get('profile',{}).get('data') or {})
 if not p or not isinstance(p.get('name'),str):raise ValueError('Character profile unavailable: '+slug)
 items={}
 for row in data.get('equipment',[])[:24]:
  slot=row.get('slot',{}).get('type');ident=row.get('item',{}).get('id')
  if isinstance(slot,str) and isinstance(ident,int) and 0<ident<100000000:
   items[slot]={'id':ident,'name':str(row.get('name',''))[:160],
    'detail':' / '.join(str(v.get('display',{}).get('display_string',''))[:100] for v in row.get('stats',[])[:12])}
 stats=[]
 for key,v in (details.get('statistics',{}).get('data') or {}).items():
  if isinstance(v,dict):v=v.get('effective',v.get('value'))
  if type(v) in (int,float) and key not in ('id',):stats.append({'name':key.replace('_',' ').title()[:60],'value':str(v)[:40]})
 return {'name':p['name'],'level':p.get('level') if type(p.get('level')) is int else None, 'race':str(p.get('race',{}).get('name',''))[:80],
  'class':str(p.get('character_class',{}).get('name',''))[:80], 'items':items,'stats':stats[:60],
  'profileAt':details.get('profile',{}).get('checkedAt'),
  'equipmentAt':details.get('equipment',{}).get('checkedAt'),
  'statisticsAt':details.get('statistics',{}).get('checkedAt'),
  'equipmentStale':details.get('equipment',{}).get('stale',True),
  'statisticsStale':details.get('statistics',{}).get('stale',True)}

def fetch(base,slug):
 req=urllib.request.Request(base+'/api/player?'+urllib.parse.urlencode({'region':'us','character':slug}),headers={'User-Agent':'GuildLayers-Armory/1.9'})
 with urllib.request.urlopen(req,timeout=30) as r:raw=r.read(2000001)
 if len(raw)>2000000:raise ValueError('Profile response too large')
 return json.loads(raw)

def main():
 parser=argparse.ArgumentParser();parser.add_argument('characters',nargs='+');parser.add_argument('--local',action='store_true')
 parser.add_argument('--output',type=Path,default=Path('D:/wforever/_forever_/Interface/AddOns/GuildLayers/ArmoryData.lua'))
 args=parser.parse_args()
 if len(args.characters)>100:parser.error('Maximum 100 characters per sync')
 base='http://127.0.0.1:8787' if args.local else 'https://osrs.services';result={}
 for name in args.characters:
  slug=name.strip().lower().replace(' ','-')
  if not re.fullmatch(r'[a-z0-9-]{2,80}',slug):raise ValueError('Invalid character slug')
  result[slug]=profile(fetch(base,slug),slug)
 # Replace only after the entire requested set validates; never execute saved Lua.
 payload='GuildLayersArmoryData='+lua({'schema':1,'exportedAt':int(time.time()),'characters':result})+'\n'
 args.output.parent.mkdir(parents=True,exist_ok=True)
 temporary=args.output.with_suffix('.tmp');temporary.write_text(payload,encoding='utf-8');os.replace(temporary,args.output)
 print('Cached',len(result),'characters. Reload UI to load the snapshot:',args.output)
if __name__=='__main__':main()
