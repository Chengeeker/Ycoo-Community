import urllib.request,urllib.parse,json,concurrent.futures

def check(module,**query):
    url='https://ycoo.net/api/mobile/index.php?'+urllib.parse.urlencode({'version':'4','module':module,**query})
    with urllib.request.urlopen(url,timeout=25) as response:
        assert response.status==200
        data=json.load(response)
    assert data.get('Version')=='4' and isinstance(data.get('Variables'),dict),module
    v=data['Variables']
    if module=='forumindex':assert len(v['forumlist'])>0
    if module=='forumdisplay':assert len(v['forum_threadlist'])>0
    if module=='viewthread':assert str(v['thread']['tid'])==str(query['tid']) and len(v['postlist'])>0
    if module=='profile':assert str(v['space']['uid'])==str(query['uid'])
    print(module,'OK')

if __name__=='__main__':
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
        jobs=[pool.submit(check,'forumindex'),pool.submit(check,'forumdisplay',fid=2),pool.submit(check,'viewthread',tid=154625),pool.submit(check,'profile',uid=1)]
        for job in jobs:job.result()
