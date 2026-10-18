"""Offline source/runtime/permission checks for W06 reproducible media."""
from pathlib import Path
import hashlib,json,struct,wave,xml.etree.ElementTree as ET
from common import ROOT


def validate():
    font=json.loads((ROOT/'assets/fonts/manifest.json').read_text())
    assert len(font['version_commit'])==40
    assert hashlib.sha256((ROOT/'assets/fonts/NotoSansSC-Regular.otf').read_bytes()).hexdigest()==font['sha256']
    assert 'SIL OPEN FONT LICENSE' in (ROOT/'assets/fonts/OFL.txt').read_text()
    icons=json.loads((ROOT/'assets/ui/manifest.json').read_text())
    assert len(icons['tools'])==16 and len(icons['feedback'])==4
    for name in icons['tools']+icons['feedback']:
        target=ROOT/f'assets/ui/{name}.svg';source=ROOT/f'art_source/week_06/ui/{name}.svg'
        assert source.read_bytes()==target.read_bytes()
        assert ET.parse(target).getroot().attrib['viewBox']=='0 0 64 64'
    entries=json.loads((ROOT/'assets/audio/manifest.json').read_text())
    assert len(entries)==17 and len({e['family'] for e in entries})==6
    for entry in entries:
        target=ROOT/entry['export'];assert target.read_bytes()==(ROOT/entry['source']).read_bytes()
        with wave.open(str(target),'rb') as stream:
            assert stream.getframerate()==48000 and stream.getnchannels()==1 and stream.getsampwidth()==2
            raw=stream.readframes(stream.getnframes())
        assert hashlib.sha256(raw).hexdigest()==entry['sha256']
        assert entry['peak_dbfs'] < -6 and abs(entry['rms_dbfs']-(-36 if entry['family']=='AUD-06' else -30))<.1
        if entry['loop']:assert entry['seam_delta']<=128
    return {'font_commit':font['version_commit'],'tool_icons':16,'feedback_icons':4,'audio_files':17,'audio_families':6,'passed':True}


if __name__=='__main__':
    result=validate();(ROOT/'reports/week_06_media.json').write_text(json.dumps(result,indent=2)+'\n')
    print('W06 MEDIA CONTRACT PASS')
