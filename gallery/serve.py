#!/usr/bin/env python3
"""Serve only the local gallery, on loopback. Regenerate its catalog before starting."""
from pathlib import Path
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
from functools import partial
import argparse, subprocess, sys

folder = Path(__file__).resolve().parent
parser = argparse.ArgumentParser()
parser.add_argument('--port', type=int, default=5176)
args = parser.parse_args()
subprocess.run([sys.executable, str(folder/'build_gallery.py')], check=True)
server = ThreadingHTTPServer(('127.0.0.1', args.port), partial(SimpleHTTPRequestHandler, directory=str(folder)))
print(f'Gallery: http://localhost:{args.port}/', flush=True)
try: server.serve_forever()
except KeyboardInterrupt: pass
finally: server.server_close()
