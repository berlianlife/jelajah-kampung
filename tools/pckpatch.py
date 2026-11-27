#!/usr/bin/env python3
"""Small delta updates for a Godot 4 .pck (pack format v2), so a web build can be
updated by sending only the files that changed.

  make : python3 pckpatch.py make OLD.pck NEW.pck PATCH.tgz
  apply: python3 pckpatch.py apply WEBDIR PATCH.tgz      (rewrites WEBDIR/index.pck + index.html sizes)
  info : python3 pckpatch.py info FILE.pck
"""
import hashlib, io, json, os, re, struct, sys, tarfile

ALIGN = 32


def read_pck(path):
    d = open(path, "rb").read()
    if d[:4] != b"GDPC":
        raise SystemExit(f"{path}: bukan file .pck Godot")
    fmt, vmaj, vmin, vpat, flags = struct.unpack_from("<5I", d, 4)
    if fmt != 2:
        raise SystemExit(f"{path}: pack format {fmt} belum didukung")
    file_base = struct.unpack_from("<Q", d, 24)[0]
    p = 32 + 16 * 4
    count = struct.unpack_from("<I", d, p)[0]
    p += 4
    entries = []
    for _ in range(count):
        n = struct.unpack_from("<I", d, p)[0]
        p += 4
        name = d[p:p + n].rstrip(b"\0").decode()
        p += n
        off, size = struct.unpack_from("<QQ", d, p)
        p += 16
        md5 = d[p:p + 16]
        p += 16
        eflags = struct.unpack_from("<I", d, p)[0]
        p += 4
        entries.append({"name": name, "data": d[file_base + off:file_base + off + size], "md5": md5, "flags": eflags})
    return {"ver": (vmaj, vmin, vpat), "flags": flags, "entries": entries}


def write_pck(pack, path):
    vmaj, vmin, vpat = pack["ver"]
    entries = pack["entries"]
    head = io.BytesIO()
    head.write(b"GDPC")
    head.write(struct.pack("<5I", 2, vmaj, vmin, vpat, pack["flags"]))
    head.write(struct.pack("<Q", 0))  # file_base placeholder
    head.write(b"\0" * 16 * 4)
    head.write(struct.pack("<I", len(entries)))
    table_size = head.tell()
    for e in entries:
        nb = e["name"].encode()
        pad = (4 - len(nb) % 4) % 4
        table_size += 4 + len(nb) + pad + 16 + 16 + 4
    file_base = (table_size + ALIGN - 1) // ALIGN * ALIGN
    blob = io.BytesIO()
    for e in entries:
        nb = e["name"].encode()
        pad = (4 - len(nb) % 4) % 4
        off = blob.tell()
        head.write(struct.pack("<I", len(nb) + pad))
        head.write(nb + b"\0" * pad)
        head.write(struct.pack("<QQ", off, len(e["data"])))
        head.write(hashlib.md5(e["data"]).digest())
        head.write(struct.pack("<I", e["flags"]))
        blob.write(e["data"])
        blob.write(b"\0" * ((ALIGN - blob.tell() % ALIGN) % ALIGN))
    out = bytearray(head.getvalue())
    struct.pack_into("<Q", out, 24, file_base)
    out += b"\0" * (file_base - len(out))
    out += blob.getvalue()
    open(path, "wb").write(out)
    return len(out)


def make(old_path, new_path, patch_path):
    old = {e["name"]: e for e in read_pck(old_path)["entries"]}
    new = read_pck(new_path)
    changed = [e for e in new["entries"] if e["name"] not in old or old[e["name"]]["data"] != e["data"]]
    manifest = {"ver": new["ver"], "flags": new["flags"],
                "order": [e["name"] for e in new["entries"]],
                "entry_flags": {e["name"]: e["flags"] for e in new["entries"]},
                "changed": [e["name"] for e in changed]}
    with tarfile.open(patch_path, "w:gz", compresslevel=9) as t:
        mb = json.dumps(manifest).encode()
        ti = tarfile.TarInfo("manifest.json"); ti.size = len(mb); t.addfile(ti, io.BytesIO(mb))
        for i, e in enumerate(changed):
            ti = tarfile.TarInfo(f"f{i}"); ti.size = len(e["data"]); t.addfile(ti, io.BytesIO(e["data"]))
    print(f"{len(changed)} file berubah dari {len(new['entries'])}; patch {os.path.getsize(patch_path)} byte")


def apply(webdir, patch_path):
    pck_path = os.path.join(webdir, "index.pck")
    old = {e["name"]: e for e in read_pck(pck_path)["entries"]}
    with tarfile.open(patch_path, "r:gz") as t:
        manifest = json.load(t.extractfile("manifest.json"))
        blobs = {name: t.extractfile(f"f{i}").read() for i, name in enumerate(manifest["changed"])}
    entries = []
    for name in manifest["order"]:
        if name in blobs:
            data = blobs[name]
        elif name in old:
            data = old[name]["data"]
        else:
            raise SystemExit(f"File {name} tidak ada di build lama maupun patch")
        entries.append({"name": name, "data": data, "flags": manifest["entry_flags"][name]})
    tmp = pck_path + ".new"
    size = write_pck({"ver": tuple(manifest["ver"]), "flags": manifest["flags"], "entries": entries}, tmp)
    html_path = os.path.join(webdir, "index.html")
    html = open(html_path, encoding="utf-8").read()
    html2, n = re.subn(r'("index\.pck"\s*:\s*)\d+', lambda m: m.group(1) + str(size), html)
    if n != 1:
        raise SystemExit("Tidak menemukan ukuran index.pck di index.html")
    open(pck_path, "wb").write(open(tmp, "rb").read())  # overwrite in place (no delete needed)
    open(html_path, "w", encoding="utf-8").write(html2)
    print(f"Build diperbarui: {len(blobs)} file diganti, index.pck {size} byte")


def info(path):
    p = read_pck(path)
    for e in p["entries"]:
        print(len(e["data"]), e["name"])


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    if cmd == "make" and len(sys.argv) == 5:
        make(*sys.argv[2:])
    elif cmd == "apply" and len(sys.argv) == 4:
        apply(*sys.argv[2:])
    elif cmd == "info" and len(sys.argv) == 3:
        info(sys.argv[2])
    else:
        print(__doc__)
