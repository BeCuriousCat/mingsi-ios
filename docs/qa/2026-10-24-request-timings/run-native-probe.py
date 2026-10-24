from http.server import ThreadingHTTPServer, BaseHTTPRequestHandler
from pathlib import Path
import json, threading, subprocess, sys, time
root=Path(__file__).parent
received=[]
class Handler(BaseHTTPRequestHandler):
    protocol_version='HTTP/1.1'
    def log_message(self, *args): pass
    def do_POST(self):
        self.rfile.read(int(self.headers.get('Content-Length','0')))
        received.append(self.path)
        if self.path=='/redirect/responses':
            self.send_response(307); self.send_header('Location','/success/responses'); self.send_header('Content-Length','0'); self.end_headers(); return
        self.send_response(200);self.send_header('Content-Type','text/event-stream');self.send_header('Connection','close');self.end_headers()
        self.close_connection=True
        text=json.dumps({'body':'synthetic readable body'},ensure_ascii=False)
        usage={'input_tokens':12,'output_tokens':8,'total_tokens':20,'output_tokens_details':{'reasoning_tokens':5},'private':'PRIVATE_USAGE_SENTINEL'}
        if self.path=='/chat/chat/completions':
            events=[{'choices':[{'delta':{'content':text}}]}, {'choices':[{'delta':{},'finish_reason':'stop'}]},
                    {'choices':[],'usage':{'prompt_tokens':12,'completion_tokens':8,'total_tokens':20,'completion_tokens_details':{'reasoning_tokens':5},'private':'PRIVATE_USAGE_SENTINEL'}}]
        elif self.path=='/cancel/responses':
            events=[{'type':'response.output_text.delta','delta':'{"body":"synthetic readable preview'}]
        elif self.path=='/limit/responses':
            events=[{'type':'response.incomplete','response':{'status':'incomplete','incomplete_details':{'reason':'max_output_tokens'},'usage':usage}}]
        else:
            events=[{'type':'response.output_text.delta','delta':text},{'type':'response.completed','response':{'status':'completed','error':None,'output':[{'type':'message','role':'assistant','status':'completed','content':[{'type':'output_text','text':text}]}],'usage':usage}}]
        try:
            for event in events:
                self.wfile.write(('data: '+json.dumps(event)+'\n\n').encode());self.wfile.flush()
            if self.path=='/cancel/responses': time.sleep(10)
            else:
                self.wfile.write(b'data: [DONE]\n\n');self.wfile.flush()
        except (BrokenPipeError,ConnectionResetError): pass
server=ThreadingHTTPServer(('127.0.0.1',0),Handler)
thread=threading.Thread(target=server.serve_forever,daemon=True);thread.start()
try:
    database=root/'native-request-timings.sqlite'
    assert not database.exists(), 'Never overwrite an earlier probe database'
    result=subprocess.run([str(Path(sys.argv[1]) / '.build/debug/NativeProbe'),str(server.server_port),str(database)],capture_output=True,text=True,timeout=40)
    (root/'native-result.json').write_text(result.stdout)
    (root/'native-runtime.log').write_text(result.stderr)
    (root/'native-server-counts.json').write_text(json.dumps({'received_count':len(received),'routes':received},indent=2)+'\n')
    if result.returncode: print('Probe failed; diagnostics preserved.');sys.exit(result.returncode)
    observations=json.loads(result.stdout)
    assert len(received)==5, received
    assert [item['exactNetworkTransactionCount'] for item in observations]==[1,2,1,1],observations
    assert [item['terminalState'] for item in observations]==['returned_data','returned_data','failed','cancelled'],observations
    assert [item['usageState'] for item in observations]==['received','received','received','pending'],observations
    for item in observations[:3]:
        assert item['serviceUsage']['inputTokens']==12 and item['serviceUsage']['outputTokens']==8
        assert item['serviceUsage']['totalTokens']==20 and item['serviceUsage']['reasoningTokens']==5
    assert 'serviceUsage' not in observations[3]
    for item in observations:
        times=item['requestTimings']
        assert times['request_transport_finished_ms'] >= 0
        assert 'first_visible_body_ms' not in times and 'response_saved_ms' not in times
        if item['scenario'] == 'limit':
            assert 'first_readable_body_ms' not in times
        else:
            assert 0 <= times['first_readable_body_ms'] <= times['request_transport_finished_ms']
    assert 'PRIVATE_' not in result.stdout
    print(json.dumps({'scenarios':4,'actual_server_requests':5,'native_network_counts':[1,2,1,1],'usage_states':['received','received','received','pending'],'paid_model_requests':0}))
finally:
    server.shutdown();server.server_close()
