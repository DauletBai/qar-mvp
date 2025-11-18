#!/usr/bin/env python3

import yaml
from pathlib import Path

EXAMPLES_DIR = Path(__file__).resolve().parents[1] / "examples" / "c"

def main():
    files = sorted(p.name for p in EXAMPLES_DIR.glob("*.c"))
    data = {"sources": files}
    out_path = Path(__file__).resolve().parents[1] / "ci" / ".c_sources.yaml"
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with open(out_path, "w") as f:
        yaml.safe_dump(data, f)

if __name__ == "__main__":
    main()
