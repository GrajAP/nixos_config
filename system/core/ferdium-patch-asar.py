#!/usr/bin/env python3
import json
import os
import struct
import sys

def patch_asar(asar_path):
    print(f"[ferdium-patch-asar] Reading ASAR archive from {asar_path}...")
    with open(asar_path, 'rb') as f:
        f.read(4) # p1 (pickle payload size for sizePickle)
        p2 = struct.unpack('<I', f.read(4))[0] # header pickle total size
        f.read(4) # p3 (header pickle payload size)
        header_len = struct.unpack('<I', f.read(4))[0] # header json string length
        header_raw = f.read(header_len)
        header = json.loads(header_raw.decode('utf-8'))
        base_offset = 8 + p2

        files_data = {}
        def read_node(node, path=''):
            if 'files' in node:
                for k, v in node['files'].items():
                    read_node(v, (path + '/' + k) if path else k)
            else:
                if not node.get('unpacked'):
                    offset = int(node['offset'])
                    size = int(node['size'])
                    f.seek(base_offset + offset)
                    files_data[path] = f.read(size)
        read_node(header)

    print(f"[ferdium-patch-asar] Read {len(files_data)} packed files.")

    # 1. Patch config.js: Add about: to ALLOWED_PROTOCOLS so isValidExternalURL('about:blank') returns true
    cfg = files_data['config.js'].decode('utf-8')
    assert 'const Je=["https:","http:","ftp:","ferdium:"];' in cfg, "config.js signature not found"
    cfg = cfg.replace(
        'const Je=["https:","http:","ftp:","ferdium:"];',
        'const Je=["https:","http:","ftp:","ferdium:","about:"];'
    )
    files_data['config.js'] = cfg.encode('utf-8')
    print("[ferdium-patch-asar] 1. config.js: added about: to ALLOWED_PROTOCOLS.")

    # 2. Patch models/Service.js: do not drop about: or call URLs in new-window listener
    srv = files_data['models/Service.js'].decode('utf-8')
    old_srv = 'if(!(0,E.isValidExternalURL)(n.url)){return}'
    assert old_srv in srv, "models/Service.js signature not found"
    new_srv = 'if(!(0,E.isValidExternalURL)(n.url)&&!n.url.startsWith("about:")&&!n.url.includes("/videocall/")&&!n.url.includes("/call/")){return}'
    srv = srv.replace(old_srv, new_srv)
    files_data['models/Service.js'] = srv.encode('utf-8')
    print("[ferdium-patch-asar] 2. models/Service.js: allowed about: and call URLs.")

    # 3. Patch index.js:
    # 3a. setWindowOpenHandler on service webviews: allow calls and about: popups as standalone resizable top-level windows
    idx = files_data['index.js'].decode('utf-8')
    old_idx = 'd.setWindowOpenHandler(({url:S,disposition:b,features:y})=>{if(b==="new-window"){return{action:"allow",outlivesOpener:false,overrideBrowserWindowOptions:{parent:o,fullscreenable:false,resizable:U(y),webPreferences:u.isLinux?{session:d.session,preload:(0,x.join)(__dirname,"webview","webauthn-popup-preload.js"),contextIsolation:true,sandbox:true}:{session:d.session}}}}(0,R.openExternalUrl)(S);return{action:"deny"}});'
    assert old_idx in idx, "index.js webview setWindowOpenHandler signature not found"
    new_idx = 'd.setWindowOpenHandler(({url:S,disposition:b,features:y})=>{const isCall=typeof S==="string"&&(S.includes("/videocall/")||S.includes("/call/")||S.includes("call_id")||S.startsWith("about:")||S==="");if(b==="new-window"||isCall){return{action:"allow",outlivesOpener:true,overrideBrowserWindowOptions:{show:true,width:1024,height:768,fullscreenable:true,resizable:true,webPreferences:{session:d.session}}}}(0,R.openExternalUrl)(S);return{action:"deny"}});'
    idx = idx.replace(old_idx, new_idx)

    # 3b. setWindowOpenHandler on web-contents-created: ensure show: true so popups are never invisible
    old_wcc = 'return{action:"allow",overrideBrowserWindowOptions:{resizable:U(r)}}'
    assert old_wcc in idx, "index.js web-contents-created signature not found"
    new_wcc = 'return{action:"allow",overrideBrowserWindowOptions:{show:true,resizable:true}}'
    idx = idx.replace(old_wcc, new_wcc)
    files_data['index.js'] = idx.encode('utf-8')
    print("[ferdium-patch-asar] 3. index.js: allowed call popups as standalone visible windows.")

    # 4. Patch webview/recipe.js: replace injected window.open with windowOpenShim preserving native WindowProxy
    rec = files_data['webview/recipe.js'].decode('utf-8')
    old_rec = 'r.ipcRenderer.sendToHost("inject-js-unsafe","window.open = window.ferdium.open;",w.notificationsClassDefinition,b.screenShareJs);'
    assert old_rec in rec, "webview/recipe.js signature not found"
    shim = '(() => { const nativeOpen = window.open; const isStr = v => typeof v === "string" && v !== ""; const openExt = u => window.ferdium.open(String(u)); window.open = function open(url, target, features) { const isCall = url && (String(url).includes("/videocall/") || String(url).includes("/call/") || String(url).includes("call_id") || String(url).startsWith("about:")); if (isCall || isStr(target) || isStr(features)) { const effFeat = isStr(features) ? features : "width=1024,height=768,resizable=yes"; return nativeOpen.call(window, url, target || "_blank", effFeat); } if (url != null && String(url) !== "") { openExt(url); return null; } const pl = { location: { href: "" }, closed: false, focus: () => {}, close: () => {} }; const poll = setInterval(() => { if (pl.location.href !== "") { clearInterval(poll); if (pl.location.href.includes("/call/") || pl.location.href.includes("call_id")) { nativeOpen.call(window, pl.location.href, target || "_blank", "width=1024,height=768,resizable=yes"); } else { openExt(pl.location.href); } } }, 0); setTimeout(() => clearInterval(poll), 1000); return pl; }; })();'
    new_rec = 'r.ipcRenderer.sendToHost("inject-js-unsafe",' + json.dumps(shim) + ',w.notificationsClassDefinition,b.screenShareJs);'
    rec = rec.replace(old_rec, new_rec)
    files_data['webview/recipe.js'] = rec.encode('utf-8')
    print("[ferdium-patch-asar] 4. webview/recipe.js: injected windowOpenShim with native WindowProxy support.")

    # Reconstruct ASAR
    payload = bytearray()
    current_offset = 0
    def update_node(node, path=''):
        nonlocal current_offset
        if 'files' in node:
            for k, v in node['files'].items():
                update_node(v, (path + '/' + k) if path else k)
        else:
            if not node.get('unpacked'):
                data = files_data[path]
                node['offset'] = str(current_offset)
                node['size'] = len(data)
                payload.extend(data)
                current_offset += len(data)
    update_node(header)

    header_json = json.dumps(header, separators=(',', ':')).encode('utf-8')
    header_str_len = len(header_json)
    pad_len = (4 - (header_str_len % 4)) % 4
    padded_str_bytes = header_json + (b'\x00' * pad_len)

    header_pickle_payload_size = len(padded_str_bytes) + 4
    size_pickle_payload = header_pickle_payload_size + 4

    tmp_out = asar_path + '.patched.tmp'
    with open(tmp_out, 'wb') as out_f:
        out_f.write(struct.pack('<I', 4))
        out_f.write(struct.pack('<I', size_pickle_payload))
        out_f.write(struct.pack('<I', header_pickle_payload_size))
        out_f.write(struct.pack('<I', header_str_len))
        out_f.write(padded_str_bytes)
        out_f.write(payload)

    os.replace(tmp_out, asar_path)
    print(f"[ferdium-patch-asar] Successfully patched {asar_path} (new size: {os.path.getsize(asar_path)} bytes).")

if __name__ == '__main__':
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <path/to/app.asar>", file=sys.stderr)
        sys.exit(1)
    patch_asar(sys.argv[1])
