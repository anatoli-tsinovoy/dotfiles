---
name: resolve-omp-attached-image-blob
description: "Resolve referenced OMP image attachments and pass their blob paths to the image tool"
condition: ["\\bImage\\s*#?\\d+\\b"]
scope: ["tool:GenerateImage", "tool:write(xd://generate_image)"]
---

The prompt references an image attached to the OMP session (`Image #N`), but the image tool needs a concrete file path. Resolve it with one Python Eval cell, setting `n` to the referenced number:

```python
import os, json
n = 1
hit = None
for line in open(os.environ["PI_SESSION_FILE"]):  # this session's own transcript
    o = json.loads(line)
    m = o.get("message") or {}
    if o.get("type") != "message" or m.get("role") != "user" or not isinstance(m.get("content"), list):
        continue
    text = "".join(c.get("text", "") for c in m["content"] if c.get("type") == "text")
    imgs = [c for c in m["content"] if c.get("type") == "image"]
    if f"[Image #{n}," in text and len(imgs) >= n:
        hit = imgs[n - 1]  # latest user message that attached Image #n
if hit is None:
    raise SystemExit(f"No user message in this session attaches Image #{n}")
base = os.path.expanduser("~/.omp/agent/blobs/" + hit["data"].removeprefix("blob:sha256:"))
ext = f"{base}.{hit['mimeType'].split('/')[1]}"
print(ext if os.path.exists(ext) else base)
```

Pass the printed path in a non-empty `input` array; a textual `Image #N` reference alone is not an input. Afterward, inspect the output to verify that the reference was used.