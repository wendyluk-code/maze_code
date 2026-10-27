"""兼容入口：用 Godot 重建召唤透明层，禁止恢复旧的外围柔边截图。"""
from pathlib import Path
import os
import subprocess

ROOT = Path(__file__).resolve().parents[1]
ENGINE = Path(r"F:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe")
profile = ROOT / "output/summon_ui/profile"
profile.mkdir(parents=True, exist_ok=True)
env = dict(os.environ, APPDATA=str(profile), LOCALAPPDATA=str(profile))
result = subprocess.run([str(ENGINE), "--headless", "--path", str(ROOT), "--script", "res://tools/slice_summon_layers.gd"], env=env, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=60)
print(result.stdout)
if result.returncode or "SUMMON_LAYERS:" not in result.stdout:
    raise RuntimeError(result.stderr)
