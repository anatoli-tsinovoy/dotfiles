---
name: resolve-omp-attached-image-blob
description: "Resolve referenced OMP image attachments and pass their blob paths to the image tool"
condition: ["\\bImage\\s*#?\\d+\\b"]
scope: ["tool:GenerateImage", "tool:write(xd://generate_image)"]
---

The prompt references an image attached to the OMP session, but the image tool needs a concrete input. Before invoking it, inspect the active session JSONL, find the corresponding `Image #N` content block and `blob:sha256:<hash>` reference, resolve the file under `~/.omp/agent/blobs/<hash>.<ext>`, and include that path in a non-empty `input` array. Do not invoke image generation using only the textual `Image #N` reference. Afterward, inspect the output to verify that the reference was used.