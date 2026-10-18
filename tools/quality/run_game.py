"""Launch the project with its locked local engine."""

import subprocess
import sys

from common import ROOT, engine_binary

raise SystemExit(subprocess.call([engine_binary(), "--path", str(ROOT), *sys.argv[1:]], cwd=ROOT))
