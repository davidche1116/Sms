import re
import sys
from pathlib import Path

xml = Path(sys.argv[1]).read_text(encoding="utf-8", errors="replace")
m = re.search(r'rotation="(\d+)"', xml)
print("rotation", m.group(1) if m else "?")
for m in re.finditer(r'<node[^>]+>', xml):
    node = m.group(0)
    def attr(name):
        mm = re.search(rf'{name}="([^"]*)"', node)
        return mm.group(1) if mm else ""
    text = attr("text")
    desc = attr("content-desc")
    bounds = attr("bounds")
    clickable = attr("clickable")
    cls = attr("class")
    if clickable == "true" or text or desc:
        print(f"{cls} click={clickable} text={text!r} desc={desc!r} {bounds}")
