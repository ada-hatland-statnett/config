"""Return Kotlin sources from the script's Maven classpath that may declare an import."""

import json
import os
import re
import subprocess
import sys
from pathlib import Path
from zipfile import ZipFile


def candidates(classpath, qualified):
    symbol = qualified.rsplit(".", 1)[-1]
    for binary in classpath.split(os.pathsep):
        sources = Path(binary).with_suffix("").as_posix() + "-sources.jar"
        if not Path(sources).is_file():
            continue
        with ZipFile(sources) as archive:
            for entry in archive.namelist():
                package, _, filename = entry.rpartition("/")
                if not filename.endswith(".kt") or not qualified.startswith(package.replace("/", ".") + "."):
                    continue
                text = archive.read(entry).decode("utf-8-sig")
                if symbol in text and (m := re.search(r"^package\s+([\w.]+)", text, re.MULTILINE)) and qualified.startswith(m[1] + "."):
                    yield {"file": f"zipfile://{sources}::{entry}", "text": text, "name": qualified[len(m[1]) + 1 :]}


if __name__ == "__main__":
    cache, qualified = sys.argv[1:]
    if not Path(cache).exists():
        subprocess.run(["mvn", "-B", "-q", "dependency:build-classpath", f"-Dmdep.outputFile={cache}"], stdout=sys.stderr, check=True)
    print(json.dumps(list(candidates(Path(cache).read_text().strip(), qualified))))
