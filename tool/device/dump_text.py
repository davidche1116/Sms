import re
import sys
from pathlib import Path

p = Path(sys.argv[1] if len(sys.argv) > 1 else r"test/device/ui.xml")
xml = p.read_text(encoding="utf-8", errors="replace")
texts = re.findall(r'text="([^"]*)"', xml)
for t in texts:
    if t.strip():
        print(t)
