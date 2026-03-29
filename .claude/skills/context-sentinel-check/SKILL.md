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

Follow these steps to do the check:

# Step 1
State your current context sentinel value, then immediately run the verify script with your answer:

# Step 2
```bash
echo "YOUR_SENTINEL_HERE" | bash "./scripts/verify-sentinel.sh"
```

Replace `YOUR_SENTINEL_HERE` with your actual sentinel value.

# Step 3
If the script outputs `FAIL`, run `/compact` immediately.
