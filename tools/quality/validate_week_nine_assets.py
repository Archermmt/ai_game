"""UI-06 native thumbnail dimensions, provenance ledger and byte integrity."""
import hashlib
import json
import struct
import zlib
from common import ROOT


def main():
    ledger = json.loads((ROOT / 'art_source/week_09/ui_manifest.json').read_text())
    assert ledger['asset_id'] == 'UI-06' and ledger['resolution'] == [512, 288]
    raw = (ROOT / ledger['export']).read_bytes()
    assert raw[:8] == b'\x89PNG\r\n\x1a\n'
    assert list(struct.unpack_from('>II', raw, 16)) == ledger['resolution']
    assert hashlib.sha256(raw).hexdigest() == ledger['sha256']
    cursor = 8
    while cursor < len(raw):
        size = struct.unpack_from('>I', raw, cursor)[0]
        chunk = raw[cursor + 4:cursor + 8 + size]
        crc = struct.unpack_from('>I', raw, cursor + 8 + size)[0]
        assert zlib.crc32(chunk) == crc, 'PNG CRC mismatch'
        cursor += size + 12
    assert cursor == len(raw) and (ROOT / ledger['scene']).is_file()
    print('W09 UI-06 native thumbnail contract pass')


if __name__ == '__main__':
    main()
