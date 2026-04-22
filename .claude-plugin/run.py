"""插件入口：根据自身位置找到 notify.py，将 stdin 透传过去。"""
import sys, subprocess
from pathlib import Path

script = Path(__file__).parent.parent / "notify.py"
result = subprocess.run([sys.executable, str(script)], stdin=sys.stdin)
sys.exit(result.returncode)
