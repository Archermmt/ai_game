"""User-authorized source MP3s stay untouched; this creates normalized runtime derivatives."""
from pathlib import Path
import subprocess,json,hashlib,concurrent.futures
import argparse
parser=argparse.ArgumentParser(description='Rebuild softened user-provided music derivatives with ffmpeg/ffprobe')
parser.add_argument('--source',type=Path,required=True)
args=parser.parse_args()
source=args.source
out=Path(__file__).resolve().parents[2]/'assets/audio/seasonal_music'
out.mkdir(parents=True,exist_ok=True)
tracks={'winter':'冬雪_暖洋洋的肉酱面_治愈.mp3','all_seasons':'四季环_暖洋洋的肉酱面_放松_民谣.mp3','summer_flowers':'夏花_暖洋洋的肉酱面_轻快.mp3','summer_breeze':'夏风蝉鸣_暖洋洋的肉酱面_轻快.mp3','pastoral':'田园慢时光_暖洋洋的肉酱面_温暖_民谣.mp3','autumn':'秋叶_暖洋洋的肉酱面.mp3','stars':'繁星_暖洋洋的肉酱面_治愈.mp3','sunny_pasture':'阳光牧场的旷野之梦_暖洋洋的肉酱面.mp3'}
def convert(item):
    key,name=item; dest=out/(key+'.mp3')
    p=subprocess.run(['ffmpeg','-y','-hide_banner','-loglevel','error','-i',str(source/name),'-vn','-af','lowpass=f=6500,loudnorm=I=-24:TP=-4:LRA=8','-ar','48000','-ac','2','-c:a','libmp3lame','-b:a','128k',str(dest)],capture_output=True,text=True);assert p.returncode==0,p.stderr
    meta=json.loads(subprocess.check_output(['ffprobe','-v','quiet','-show_entries','format=duration','-of','json',str(dest)]))
    result=subprocess.run(['ffmpeg','-hide_banner','-i',str(dest),'-af','loudnorm=I=-24:TP=-4:LRA=8:print_format=json','-f','null','-'],capture_output=True,text=True)
    assert result.returncode==0,result.stderr
    stats=json.JSONDecoder().raw_decode(result.stderr[result.stderr.rfind('{'):])[0]
    return {'id':key,'source_file':name,'source_sha256':hashlib.sha256((source/name).read_bytes()).hexdigest(),'export':str(dest.relative_to(Path(__file__).resolve().parents[2])),'sha256':hashlib.sha256(dest.read_bytes()).hexdigest(),'seconds':float(meta['format']['duration']),'integrated_lufs':float(stats['input_i']),'true_peak_dbtp':float(stats['input_tp']),'rights':'User-provided music, authorized for this project by user; no independent distribution license supplied'}
with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:rows=list(pool.map(convert,tracks.items()))
(out/'manifest.json').write_text(json.dumps({'processing':'ffmpeg lowpass6500Hz; loudnorm I=-24 TP=-4 LRA=8; MP3 128k stereo48kHz','ffmpeg':subprocess.check_output(['ffmpeg','-version'],text=True).splitlines()[0],'tracks':rows},ensure_ascii=False,indent=2)+'\n')
print(json.dumps([{k:r[k] for k in ['id','seconds','integrated_lufs','true_peak_dbtp']} for r in rows],indent=2))
