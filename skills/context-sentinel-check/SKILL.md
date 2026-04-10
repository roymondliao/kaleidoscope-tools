---
name: "kaleidoscope:context-sentinel-check"
description: "Verify agent still remembers the context sentinel. If forgotten, automatically runs /compact."
allowed-tools:
  - Read
  - Write
  - Bash
user-invocable: true
disable-model-invocation: true
---

A random sentinel is auto-generated at session start and injected into your context.
The plaintext is NOT stored on disk — only a SHA-256 hash. You cannot look it up.

# Step 1
State your current context sentinel value, then immediately run the verify script with your answer:

# Step 2
```bash
echo "YOUR_SENTINEL_HERE" | bash "${CLAUDE_PROJECT_DIR}/skills/context-sentinel-check/scripts/verify-sentinel.sh"
```

Replace `YOUR_SENTINEL_HERE` with your actual sentinel value.

# Step 3
If the script outputs `FAIL`, run `/compact` immediately.
