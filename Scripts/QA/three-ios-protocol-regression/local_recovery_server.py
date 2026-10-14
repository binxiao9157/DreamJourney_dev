"""Local test server + independent default Worker, controlled model HTTP only.
No production endpoints/credentials; config contains disposable local login.
"""
import os,sys,json,uuid,time,threading,socket,subprocess,signal,importlib.util
from hashlib import sha256
from pathlib import Path
from dataclasses import replace
from datetime import datetime,timezone,timedelta
ROOT=Path(os.environ['DJ_TEST_BACKEND_ROOT']).resolve();sys.path.insert(0,str(ROOT))
import psycopg,httpx,uvicorn
from fastapi import HTTPException,FastAPI
from contextlib import asynccontextmanager
from app.db.migrator import PostgresMigrator,default_migrations_dir
from app.services.postgres_store import PostgresStore
import app.main as main
from app.core.config import Settings
from tests.test_owner_truth_live_long_memory_pipeline import _typed_memory
spec=importlib.util.spec_from_file_location('helper',ROOT/'scripts/backend-owner-truth-live-candidate-formal-postgres-smoke.py')
h=importlib.util.module_from_spec(spec);spec.loader.exec_module(h)
OUT=Path(os.environ['LAB_LOCAL_OUT']);OUT.mkdir(parents=True,exist_ok=False)
DB='dj_tests_repair_'+uuid.uuid4().hex[:8];ADMIN_DSN=os.environ['DJ_TEST_PG_ADMIN_DSN']
from psycopg.conninfo import conninfo_to_dict,make_conninfo
assert conninfo_to_dict(ADMIN_DSN).get('host')=='127.0.0.1', 'Only disposable loopback PostgreSQL is allowed'
DSN=make_conninfo(ADMIN_DSN,dbname=DB)
with psycopg.connect(ADMIN_DSN,autocommit=True) as c:
    c.execute(psycopg.sql.SQL("CREATE DATABASE {} TEMPLATE template0 ENCODING 'UTF8'").format(psycopg.sql.Identifier(DB)))
PostgresMigrator(dsn=DSN,migrations_dir=default_migrations_dir(),build_id='local-recovery-four').apply()
store=PostgresStore(dsn=DSN,pool_min_size=1,pool_max_size=8);store.open_pool(wait=True)
main.store=store;main.settings=replace(main.settings,owner_truth_live_recovery_enabled=True,owner_truth_live_long_memory_pipeline_enabled=True)
main.BACKEND_API_TOKEN='';main.AUTH_LEGACY_PHONE_LOGIN_ENABLED=True;main.AUTH_ROUTE_MODE='enforce';main.AUTH_OWNERSHIP_MODE='enforce';main.OWNER_TRUTH_CANDIDATE_REVIEW_QA_ENABLED=False
SCENES={};order=['short6','logical10'];active={'name':None};events=[]
for name,n,groups,duration in [('short6',6,1,90),('logical10',30,2,600)]:
    texts=[f'2026年10月14日合成{name}场，我把第{i+1}张叶片照片放进第{i//15+1}本观察册。' for i in range(n)]
    topic_for={t:f'{name}-album-{i//15}' for i,t in enumerate(texts)}
    turns=[]
    for i,t in enumerate(texts):
        turns.extend([dict(index=i*2+1,role='user',text=t),dict(index=i*2+2,role='assistant',text=f'已收到第 {i+1} 条合成信息。')])
    SCENES[name]=dict(texts=texts,turns=turns,memories=[_typed_memory(t,[i*2+1]) for i,t in enumerate(texts)],
        topicFor=topic_for,summaries={},expectedFacts=texts,expectedThemes=groups,logicalDurationSeconds=duration)
handlers={};model_requests=[]
settings=replace(main.settings,store_backend='postgres',database_url=DSN,deepseek_api_key='local-controlled-only',
    async_effect_v1_enabled=True,async_effect_worker_enabled=True,owner_truth_candidate_extraction_worker_enabled=True,
    owner_truth_live_memory_organization_enabled=True)
for name,scene in SCENES.items():handlers[name]=h.controlled_extractor(settings,turns=scene['turns'],memories=scene['memories'],store=store,expose_handler=True)[0]
def model(request):
    name=active['name'];assert name is not None
    body=json.loads(request.content);prompt=body['messages'][1]['content'];scene=SCENES[name]
    if body.get('response_format',{}).get('type')=='json_object' and not any('json' in m.get('content','').lower() for m in body.get('messages',[])):
        return httpx.Response(400,request=request,json={'error':{'code':'invalid_request_error'}})
    assert type(body.get('max_tokens')) is int and 0<body['max_tokens']<=8192

    model_requests.append(dict(scene=name,bytes=len(request.content),at=time.time()))
    try:data=json.loads(prompt)
    except (ValueError,TypeError):return handlers[name](request)
    if isinstance(data,dict) and 'material' in data:
        # Four fixtures are separate dated events. Cross-scene positive/negative
        # relations have their own dedicated PG test with explicit target truth.
        # Independent synthetic topics; no existing memory is treated as the same event.
        if 'proposal' in data:
            result=dict(schemaVersion='owner-truth-live-theme-relation-support-v1',inputHash=data['inputHash'],proposalHash=data['proposalHash'],
                verdict='supported',sameSubjectEvent=False,compatibleTime=True,correctionsResolved=False,summarySupported=True)
        else:
            result=dict(schemaVersion='owner-truth-live-theme-relation-v1',inputHash=data['inputHash'],relation='none',targetTopicId=None)
        return httpx.Response(200,request=request,json={'choices':[{'finish_reason':'stop','message':{'content':json.dumps(result)}}]})
    if isinstance(data,dict) and 'context' in data and 'themes' in data:
        result=dict(schemaVersion='owner-truth-live-theme-safety-v1',inputHash=data['inputHash'],
            themes=[dict(key=t['key'],verdict='safe') for t in data['themes']])
        return httpx.Response(200,request=request,json={'choices':[{'finish_reason':'stop','message':{'content':json.dumps(result)}}]})
    if not isinstance(data,dict) or 'atoms' not in data:return handlers[name](request)
    if 'proposal' in data:
        result=dict(schemaVersion='owner-truth-live-theme-support-v1',inputHash=data['inputHash'],proposalHash=data['proposalHash'],
            themes=[dict(key=g['key'],atomIds=g['atomIds'],evidenceIds=g['evidenceIds'],verdict='supported',sameSubjectEvent=True,compatibleTime=True,correctionsResolved=True) for g in data['proposal']['themes']])
    else:
        grouped={};omitted=[]
        for atom in data['atoms']:
            if atom['supportState']!='supported':omitted.append(atom['atomId']);continue
            content=atom['content'];text=content.get('claim') or content.get('summary')
            key=scene['topicFor'].get(text)
            if key is None:
                keys={k for fact,k in scene['topicFor'].items() if fact in (text or '')}
                key=next(iter(keys)) if len(keys)==1 else None
            assert key is not None,('unrecognized fact',text)
            grouped.setdefault(key,[]).append(atom)
        result=dict(schemaVersion='owner-truth-live-theme-v1',inputHash=data['inputHash'],omittedAtomIds=omitted,
            themes=[dict(key=k,title=k,summary='；'.join(dict.fromkeys(a['content'].get('claim') or a['content'].get('summary') for a in atoms)),atomIds=[a['atomId'] for a in atoms],
                evidenceIds=sorted({e for a in atoms for e in a['evidenceIds']}),dimensions=sorted({d for a in atoms for d in a['dimensions']})) for k,atoms in grouped.items()])
    return httpx.Response(200,request=request,json={'usage':{'prompt_tokens':100,'completion_tokens':80},'choices':[{'finish_reason':'stop','message':{'content':json.dumps(result,ensure_ascii=False)}}]})
model_server,model_thread=h.start_controlled_model_http(model)
# Production CLI default Worker is a separate process, never a manually driven helper.
env=dict(os.environ,PYTHONUNBUFFERED='1',STORE_BACKEND='postgres',DATABASE_URL=DSN,DEEPSEEK_API_KEY='local-controlled-only',
    DEEPSEEK_BASE_URL=f'http://127.0.0.1:{model_server.server_port}/chat/completions',ASYNC_EFFECT_V1_ENABLED='true',
    ASYNC_EFFECT_WORKER_ENABLED='true',OWNER_TRUTH_CANDIDATE_EXTRACTION_WORKER_ENABLED='true',
    OWNER_TRUTH_LIVE_MEMORY_ORGANIZATION_ENABLED='true',OWNER_TRUTH_LIVE_LONG_MEMORY_PIPELINE_ENABLED='true',
    OWNER_TRUTH_LIVE_RECOVERY_ENABLED='true',OWNER_TRUTH_WORKER_POLL_SECONDS='0.1')
worker_log=open(OUT/'four-scene-worker.log','w')
worker=subprocess.Popen([sys.executable,'-m','app.async_effects.owner_truth_candidate_extraction_worker','--loop','--poll-seconds','0.1','--retry-seconds','1'],cwd=ROOT,env=env,stdout=worker_log,stderr=subprocess.STDOUT)
completed=[]
@asynccontextmanager
async def lifespan(app):
    async with main.app.router.lifespan_context(main.app):yield
harness=FastAPI(lifespan=lifespan)
confirmation_requests=[]
api_requests=[]
@harness.post('/__recovery/{name}/begin')
def begin(name:str):
    if name not in SCENES or order[len(completed)]!=name:raise HTTPException(409,'independent short gate/order required')
    active['name']=name;events.append(dict(event='begin',name=name,time=time.time()));return {'ok':True}
@harness.post('/__recovery/{name}/verify')
def verify(name:str,payload:dict):
    if active['name']!=name:raise HTTPException(409,'scene mismatch')
    scene=SCENES[name];product=payload['productSessionId'];ledger=payload['ledger']
    with psycopg.connect(DSN) as c:
        rows=c.execute("""SELECT m.id,m.content_payload,m.client_sequence_number,m.author FROM owner_truth.conversation_messages m
            JOIN owner_truth.interview_sessions i ON i.id=m.session_id WHERE i.product_session_id=%s ORDER BY m.client_sequence_number""",(product,)).fetchall()
        assert len(rows)==len(scene['turns'])==len(ledger),(len(rows),len(scene['turns']),len(ledger))
        for row,truth,item in zip(rows,scene['turns'],ledger):
            assert str(row[0])==item['messageId']
            assert row[1]['text']==truth['text']
            assert row[2]==truth['index']==item['sequence']
            assert row[3]==('owner' if truth['role']=='user' else 'assistant')==item['role']
            assert sha256(row[1]['text'].encode()).hexdigest()==item['bodyDigest']
            assert item['rawCanonicalTurnID']==item['diskCanonicalTurnID']
            assert item['rawHandoffID'] in item['diskHandledHandoffIDs']
        snaps=c.execute("""SELECT p.snapshot,p.source_id,s.metadata,p.publication_manifest FROM owner_truth.live_recovery_snapshots p
            JOIN owner_truth.interview_sessions i ON i.id=p.session_id JOIN owner_truth.sources s ON s.id=p.source_id
            WHERE i.product_session_id=%s AND p.state='published' ORDER BY p.revision DESC LIMIT 1""",(product,)).fetchone()
        assert snaps and snaps[0]['missingRanges']==[]
        assert snaps[0]['endPositionKnown'] is True and snaps[0]['finalSequence']==len(rows)
        assert snaps[0]['receivedRanges']==[[1,len(rows)]]
        source_turns=snaps[2]['conversationTurns'];assert len(source_turns)==len(rows)
        for st,row in zip(source_turns,rows):
            assert st['messageId']==str(row[0]) and st['index']==row[2] and st['text']==row[1]['text']
            assert st['contentHash']==sha256(row[1]['text'].encode()).hexdigest()
        scene['verifiedSource']=str(snaps[1]);scene['product']=product
        scene['ledgerHash']=sha256(json.dumps(ledger,sort_keys=True).encode()).hexdigest()
    with psycopg.connect(DSN) as c:
        session=c.execute('SELECT id FROM owner_truth.interview_sessions WHERE product_session_id=%s',(product,)).fetchone()[0]
    return {'ok':True,'sourceID':scene['verifiedSource'],'sessionID':str(session),'messageCount':len(rows)}
@harness.post('/__recovery/{name}/complete')
def complete(name:str,payload:dict):
    if active['name']!=name or order[len(completed)]!=name:raise HTTPException(409,'wrong gate')
    assert payload['facts']==sorted(SCENES[name]['expectedFacts']),payload
    assert payload['themeCount']==SCENES[name]['expectedThemes'],payload
    assert SCENES[name].get('verifiedSource'),'ledger not independently verified'
    # A fresh connection reads committed PG state, not API/Worker object caches.
    with psycopg.connect(DSN) as c:
        source=SCENES[name]['verifiedSource']
        topics=c.execute("""SELECT t.state,r.payload FROM owner_truth.live_memory_topics t JOIN owner_truth.live_memory_topic_revisions r
            ON r.topic_id=t.id AND r.version=t.current_version WHERE r.source_id=%s""",(source,)).fetchall()
        assert len(topics)==SCENES[name]['expectedThemes'] and all(t[0]=='accepted' for t in topics)
        members={v['candidateId']:v for _,t in topics for v in t['members'].values()}
        # V5 can attach corroborating evidence to an existing memory. Resolve
        # each candidate through its committed group receipt, not creation Source.
        results=c.execute("SELECT result_payload FROM owner_truth.memory_changeset_group_receipts").fetchall()
        committed={m['candidateId']:m for (r,) in results for m in r['members'] if m['candidateId'] in members}
        assert set(committed)==set(members)
        assert {m['memoryId'] for m in committed.values()}==set(payload['memoryIDs'])
        facts=[];outcomes={}
        for candidate,member in committed.items():
            receipt=c.execute("SELECT candidate_id FROM owner_truth.decision_receipts WHERE id=%s",(member['receiptId'],)).fetchone()
            assert receipt and str(receipt[0])==candidate
            row=c.execute("SELECT payload FROM owner_truth.memory_versions WHERE id=%s AND memory_id=%s AND is_current",(member['memoryVersionId'],member['memoryId'])).fetchone()
            assert row
            content=row[0]['content'];facts.append(content.get('statement') or content.get('claim') or content.get('summary'))
            outcomes[member['activationOutcome']]=outcomes.get(member['activationOutcome'],0)+1
        facts.sort();payload['activationOutcomes']=outcomes
        assert facts==sorted(SCENES[name]['expectedFacts']),(facts,SCENES[name]['expectedFacts'])
    # All current-protocol scenes must negotiate and close recovery, never legacy completion.
    paths=[r['path'] for r in api_requests if r['scene']==name]
    assert any(p.endswith('/recovery') for p in paths),paths
    controls=[r for r in api_requests if r['scene']==name]
    assert any(r.get('recoveryProtocol')=='live-recovery-v1' for r in controls)
    assert any(r.get('action')=='close' and r.get('finalSequence')==len(SCENES[name]['turns']) for r in controls)
    assert not any(p.endswith(('/end','/acknowledgement','/candidate-proposal/admit')) for p in paths),paths
    (OUT/'http-requests.json').write_text(json.dumps(api_requests,indent=2))
    payload['ledgerHash']=SCENES[name]['ledgerHash']
    completed.append(name);events.append(dict(event='complete',name=name,**payload));(OUT/'four-scene-results.json').write_text(json.dumps(events,ensure_ascii=False,indent=2))
    return {'ok':True}
listener=socket.socket();listener.bind(('127.0.0.1',0));listener.listen(128);port=listener.getsockname()[1]
class ObserveAPI:
    def __init__(self,app):self.app=app
    async def __call__(self,scope,receive,send):
        status=None
        record=dict(scene=active['name'],method=scope.get('method'),path=scope.get('path'))
        if scope.get('type')=='http': api_requests.append(record)
        chunks=[]
        async def observed_receive():
            message=await receive()
            if message['type']=='http.request':
                chunks.append(message.get('body',b''))
                if not message.get('more_body',False):
                    try:
                        body=json.loads(b''.join(chunks))
                        for key in ['recoveryProtocol','protocol','generation','action','finalSequence']:
                            if key in body:record[key]=body[key]
                    except (ValueError,TypeError):pass
            return message
        if scope.get('method')=='POST' and '/live-memory-themes/' in scope.get('path','') and scope['path'].endswith('/confirm'):confirmation_requests.append(scope['path'])
        async def observed(message):
            nonlocal status
            if message['type']=='http.response.start':status=message['status']
            if message['type']=='http.response.body' and status and status>=400:
                try:
                    obj=json.loads(message.get('body',b'{}'))
                    print('LOCAL HTTP ERROR',scope.get('path'),status,obj,flush=True)
                except ValueError:pass
            await send(message)
        await self.app(scope,observed_receive,observed)
harness.mount('/',ObserveAPI(main.app))
server=uvicorn.Server(uvicorn.Config(harness,lifespan='on',log_level='error'));thread=threading.Thread(target=lambda:server.run(sockets=[listener]),daemon=True);thread.start()
limit=time.monotonic()+20
while not server.started and time.monotonic()<limit:time.sleep(.02)
if not server.started:
    worker.terminate();worker.wait(timeout=10);raise RuntimeError('local API startup failed')
client=httpx.Client(base_url=f'http://127.0.0.1:{port}',timeout=20)
res=client.post('/auth/login',json={'phone':'13900000430','nickname':'Local recovery four','password':'local-fixture-only'});assert res.status_code==200
login=res.json();owner=login['user']['id'];vault='recovery-four-scene'
main.RELEASE_POLICY_CLOSED_PILOT_OWNER_IDS=frozenset({owner})
main.RELEASE_POLICY_SERVICE.closed_pilot_enabled_features=frozenset({'echoTextInput','ownerTruthCandidateReview'})
with psycopg.connect(DSN) as c:c.execute('INSERT INTO owner_truth.vaults(vault_id,owner_subject_id) VALUES(%s,%s)',(vault,owner))
config=Path('/private/tmp/dj-three-tests-recovery-config.json');config.write_text(json.dumps(dict(baseURL=str(client.base_url),userID=owner,vaultID=vault,authorityEpoch='local-recovery-policy',auth=login['auth'],
    validationMode=os.environ.get('LAB_VALIDATION_MODE',''),scenes=[dict(name=n,**{k:SCENES[n][k] for k in ['texts','expectedFacts','expectedThemes','logicalDurationSeconds']}) for n in order]),ensure_ascii=False));config.chmod(0o600)
(OUT/'four-scene-runtime.json').write_text(json.dumps({'database':DB,'port':port,'workerPID':worker.pid,'serverPID':os.getpid(),'provider':'controlled-local-HTTP'}))
print('READY isolated recovery short6 then logical10',flush=True)
stop=threading.Event();signal.signal(signal.SIGTERM,lambda *_:stop.set());signal.signal(signal.SIGINT,lambda *_:stop.set())
try:
    while not stop.wait(1):
        if worker.poll() is not None:raise RuntimeError('Worker stopped unexpectedly')
finally:
    worker.terminate();worker.wait(timeout=15);worker_log.close();client.close();server.should_exit=True;thread.join(timeout=10)
    model_server.shutdown();model_thread.join(timeout=5);store.close_pool();config.unlink(missing_ok=True)
    (OUT/'four-scene-model-requests.json').write_text(json.dumps(model_requests))
