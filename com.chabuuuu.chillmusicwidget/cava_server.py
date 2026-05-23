#!/usr/bin/env python3
# cava_server.py - Pure Python WebSocket Server for CAVA Real-Time Streaming
# Zero external dependencies. Works on standard Python out-of-the-box!

import os
import sys
import time
import socket
import hashlib
import base64
import subprocess
import threading

PORT = 24862
clients = []
clients_lock = threading.Lock()

# ─── 1. Spawn CAVA Process ────────────────────────────────────────────────────
def run_cava():
    config_dir = os.path.expanduser("~/.config/chill-music-widget")
    os.makedirs(config_dir, exist_ok=True)
    config_path = os.path.join(config_dir, "cava.conf")
    
    # Write optimized 15-bar CAVA config
    with open(config_path, "w") as f:
        f.write("""
[general]
bars = 15
framerate = 60

[input]
method = pulse
source = auto

[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 36
""")

    # Spawn CAVA
    try:
        proc = subprocess.Popen(["cava", "-p", config_path], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
        print("CAVA subprocess spawned successfully.")
        
        while proc.poll() is None:
            line = proc.stdout.readline()
            if not line:
                continue
                
            # CAVA ASCII format outputs bar heights separated by semicolons (e.g. "12;24;32;...")
            parts = line.strip().strip(";").split(";")
            if len(parts) >= 15:
                # Format as comma-separated string for WebSocket
                message = ",".join(parts[:15])
                broadcast(message)
                
    except Exception as e:
        print(f"Error running CAVA: {e}")

# ─── 2. WebSocket Framing Helper ──────────────────────────────────────────────
def encode_frame(message):
    payload = message.encode("utf-8")
    payload_len = len(payload)
    
    if payload_len <= 125:
        header = bytes([129, payload_len])
    elif payload_len >= 126 and payload_len <= 65535:
        header = bytes([129, 126]) + payload_len.to_bytes(2, byteorder="big")
    else:
        header = bytes([129, 127]) + payload_len.to_bytes(8, byteorder="big")
        
    return header + payload

# ─── 3. Handshake Helper ──────────────────────────────────────────────────────
def handle_handshake(sock):
    data = sock.recv(1024).decode("utf-8", errors="ignore")
    headers = {}
    for line in data.split("\r\n")[1:]:
        if ":" in line:
            k, v = line.split(":", 1)
            headers[k.strip().lower()] = v.strip()
            
    key = headers.get("sec-websocket-key")
    if not key:
        return False
        
    # Calculate response key
    guid = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
    accept = base64.b64encode(hashlib.sha1((key + guid).encode("utf-8")).digest()).decode("utf-8")
    
    response = (
        "HTTP/1.1 101 Switching Protocols\r\n"
        "Upgrade: websocket\r\n"
        "Connection: Upgrade\r\n"
        f"Sec-WebSocket-Accept: {accept}\r\n\r\n"
    )
    sock.sendall(response.encode("utf-8"))
    return True

# ─── 4. Client Communication ──────────────────────────────────────────────────
def client_thread(sock, addr):
    print(f"Client connected from {addr}")
    try:
        if not handle_handshake(sock):
            sock.close()
            return
            
        with clients_lock:
            clients.append(sock)
            
        # Keep connection open
        while True:
            # We don't expect incoming data, but this keeps the socket alive and detects closure
            data = sock.recv(1024)
            if not data:
                break
                
    except Exception:
        pass
    finally:
        with clients_lock:
            if sock in clients:
                clients.remove(sock)
        try:
            sock.close()
        except:
            pass
        print(f"Client {addr} disconnected.")

def broadcast(message):
    frame = encode_frame(message)
    dead_clients = []
    
    with clients_lock:
        for client in clients:
            try:
                client.sendall(frame)
            except Exception:
                dead_clients.append(client)
                
        for client in dead_clients:
            if client in clients:
                clients.remove(client)
                try:
                    client.close()
                except:
                    pass

# ─── 5. Start Server ──────────────────────────────────────────────────────────
def start_server():
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    
    try:
        server.bind(("127.0.0.1", PORT))
        server.listen(5)
        print(f"WebSocket Server started on ws://localhost:{PORT}")
    except Exception as e:
        print(f"Could not start server: {e}")
        sys.exit(1)
        
    # Start CAVA thread
    cava_t = threading.Thread(target=run_cava, daemon=True)
    cava_t.start()
    
    # Accept connections
    try:
        while True:
            sock, addr = server.accept()
            t = threading.Thread(target=client_thread, args=(sock, addr), daemon=True)
            t.start()
    except KeyboardInterrupt:
        pass
    finally:
        server.close()

if __name__ == "__main__":
    start_server()
