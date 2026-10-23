import http.server,json,threading,time,argparse
from pathlib import Path
parser=argparse.ArgumentParser()
parser.add_argument('--output',type=Path,required=True)
args=parser.parse_args()
records=[]
lock=threading.Lock()
class Handler(http.server.BaseHTTPRequestHandler):
 protocol_version='HTTP/1.1'
 def do_GET(self):
  with lock:
   records.append(self.path)
   args.output.write_text(json.dumps(records))
  if self.path=='/redirect':
   self.send_response(302);self.send_header('Location','/success');self.send_header('Content-Length','0');self.end_headers();return
  if self.path=='/cancel':
   self.send_response(200);self.send_header('Content-Type','text/event-stream');self.end_headers()
   self.wfile.write(b'data: synthetic\n\n');self.wfile.flush()
   time.sleep(8)
   self.close_connection=True
   return
  body=b'data: synthetic\n\ndata: [DONE]\n\n'
  self.send_response(200);self.send_header('Content-Type','text/event-stream');self.send_header('Content-Length',str(len(body)));self.end_headers();self.wfile.write(body)
 def log_message(self,*args): pass
server=http.server.ThreadingHTTPServer(('127.0.0.1',0),Handler)
print(server.server_address[1],flush=True)
server.serve_forever()
