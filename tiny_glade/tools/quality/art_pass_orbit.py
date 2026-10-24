"""Record a real 360-degree runtime orbit; no offline scene render."""
import hashlib
import json
import subprocess
from common import ROOT, engine_binary
from run_checks import run_step
from art_pass_render_checks import production_files

out = ROOT / "reports/art_pass_01/native"
out.mkdir(parents=True, exist_ok=True)
movie = out / "orbit.avi"
video = out / "orbit.mp4"
before = production_files()
run_step("art_01_orbit", [engine_binary(), "--path", str(ROOT), "--resolution", "1280x720",
    "--fixed-fps", "30", "--write-movie", str(movie), "--quit-after", "420", "--",
    "--qa-settings", "--w08-orbit", "--hide-ui"])
subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(movie), "-c:v", "libx264", "-crf", "20",
    "-pix_fmt", "yuv420p", "-an", str(video)], check=True)
probe = json.loads(subprocess.check_output(["ffprobe", "-v", "error", "-show_entries",
    "stream=codec_name,width,height,nb_frames:format=duration", "-of", "json", str(video)], text=True))
assert int(probe["streams"][0]["nb_frames"]) >= 420
assert production_files() == before
result = {"probe": probe, "sha256": hashlib.sha256(video.read_bytes()).hexdigest(),
          "bytes": video.stat().st_size, "rotation_degrees": 360.96, "production_unchanged": True}
(out / "orbit.json").write_text(json.dumps(result, indent=2) + "\n")
movie.unlink()
movie.with_suffix(".wav").unlink(missing_ok=True)
print("Native full orbit recorded", video)
