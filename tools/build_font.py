"""Build the renamed, OFL-licensed MagicTowerCJK font subset.
Requires fontTools. Uses only a caller-specified, locally installed Noto TTC.
Default: python tools/build_font.py
Temporary complete SC face: python tools/build_font.py --full
After changing UI strings, rerun default and then --check.
"""
from pathlib import Path
import argparse
import hashlib
import json
import re
import unicodedata
from fontTools import subset
from fontTools.ttLib import TTFont, TTCollection

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets' / 'fonts'
FAMILY = 'MagicTowerCJK'
POSTSCRIPT = 'MagicTowerCJK-Regular'
DEFAULT_SOURCE = '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc'
DEFAULT_COPYRIGHT = '/usr/share/doc/fonts-noto-cjk/copyright'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def text_coverage():
    paths = sorted((ROOT/'scripts').rglob('*.gd'))
    paths += [ROOT/'project.godot']
    codepoints = set(range(0x20,0x7f))
    scanned = []
    for path in paths:
        text=path.read_text(encoding='utf-8')
        codepoints.update(ord(c) for c in text if c.isprintable())
        for escaped in re.finditer(r'\\(?:u([0-9a-fA-F]{4})|U([0-9a-fA-F]{8}))',text):
            cp=int(escaped.group(1) or escaped.group(2),16)
            if cp<=0x10ffff and chr(cp).isprintable():codepoints.add(cp)
        scanned.append({'path':str(path.relative_to(ROOT)),'sha256':sha(path)})
    return codepoints,scanned


def find_sc(source):
    collection=TTCollection(str(source),lazy=True)
    for i,font in enumerate(collection.fonts):
        if font['name'].getDebugName(6)=='NotoSansCJKsc-Regular':
            collection.close()
            return i
    collection.close()
    raise ValueError('The supplied TTC has no NotoSansCJKsc-Regular face')


def missing_text(codes):
    return ['U+%04X %s'%(cp,unicodedata.name(chr(cp),'UNNAMED')) for cp in sorted(codes)]


def license_text(copyright_path,font):
    packaged=copyright_path.read_text(encoding='utf-8')
    marker='\nLicense: SIL-1.1\n'
    if marker not in packaged:
        raise ValueError('Supplied copyright file lacks full SIL-1.1 block')
    block=packaged.rsplit(marker,1)[1].split('\nLicense:',1)[0]
    lines=[]
    for line in block.splitlines():
        if line.startswith(' '):line=line[1:]
        lines.append('' if line=='.' else line)
    if not any('TERMINATION' in line for line in lines) or not any('DISCLAIMER' in line for line in lines):
        raise ValueError('Incomplete OFL license; refusing to redistribute font')
    notice=font['name'].getDebugName(0) or ''
    return 'Copyright 2010-2012 Google Corporation (distribution copyright notice).\n'+notice+'\n\n'+'\n'.join(lines).strip()+'\n'


def rename(font,license_body):
    table=font['name']
    replacement={1:FAMILY,2:'Regular',3:'MagicTowerCJK-Regular;derived-subset',
                 4:FAMILY+' Regular',6:POSTSCRIPT,16:FAMILY,17:'Regular',18:FAMILY+' Regular',
                 21:FAMILY,22:'Regular',13:license_body,14:'https://openfontlicense.org/'}
    # Preserve original authors/manufacturer/copyright. Rename every localized
    # primary family/full/PostScript record so no old primary name remains.
    for record in list(table.names):
        if record.nameID in replacement:
            table.setName(replacement[record.nameID],record.nameID,record.platformID,record.platEncID,record.langID)
    for name_id,value in replacement.items():
        table.setName(value,name_id,3,1,0x409)
    if 'CFF ' in font:
        cff=font['CFF '].cff
        cff.fontNames=[POSTSCRIPT]
        top=cff.topDictIndex[0]
        top.FamilyName=FAMILY
        top.FullName=FAMILY+' Regular'


def verify_font(path,required):
    font=TTFont(str(path),lazy=False,recalcTimestamp=False)
    cmap=font.getBestCmap()
    missing=required-set(cmap)
    if missing:raise ValueError('Missing UI characters: '+', '.join(missing_text(missing)))
    for name_id in [1,4,6,16]:
        value=font['name'].getDebugName(name_id)
        if not value or not value.startswith(FAMILY):
            raise ValueError('Unrenamed primary font name ID %s: %r'%(name_id,value))
    if 'CFF ' in font and font['CFF '].cff.fontNames!=[POSTSCRIPT]:
        raise ValueError('Unrenamed CFF PostScript name')
    info={'mapped_codepoints':len(cmap),'glyphs':font['maxp'].numGlyphs,
          'required_codepoints':len(required),'missing':[],
          'family':font['name'].getDebugName(1),'postscript':font['name'].getDebugName(6)}
    font.close()
    return info


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--source',default=DEFAULT_SOURCE)
    parser.add_argument('--copyright',default=DEFAULT_COPYRIGHT)
    parser.add_argument('--full',action='store_true',help='Temporary full SC face for layout; default builds a compact subset')
    parser.add_argument('--check',action='store_true',help='Verify current OTF covers current scripts, without rebuilding')
    args=parser.parse_args()
    required,scanned=text_coverage()
    output=OUT/(FAMILY+'.otf')
    if args.check:
        print(json.dumps(verify_font(output,required),ensure_ascii=False,indent=2))
        return
    source=Path(args.source);copyright_path=Path(args.copyright)
    index=find_sc(source)
    font=TTFont(str(source),fontNumber=index,recalcTimestamp=False)
    source_cmap=font.getBestCmap()
    missing=required-set(source_cmap)
    if missing:raise ValueError('Source font cannot cover required text: '+', '.join(missing_text(missing)))
    license_body=license_text(copyright_path,font)
    source_names={str(i):font['name'].getDebugName(i) for i in [0,1,3,5,6,8,9,13,14]}
    # Common punctuation, arrows, spaces and mathematical UI signs are retained
    # where present, while every actual printable source character is mandatory.
    optional=set(range(0xa0,0x100))|set(range(0x2000,0x2070))|set(range(0x2190,0x2200))
    optional|={0x00b7,0x00d7,0x00f7,0x2212,0x2260,0x2264,0x2265,0x25a0,0x25a1,0x25b2,0x25bc,0x25cf,0x2605,0x3000,0x3001,0x3002,0xff1a,0xff1b,0xff0c,0xff01,0xff1f}
    kept=required|(optional&set(source_cmap))
    if not args.full:
        options=subset.Options()
        options.name_IDs=['*'];options.name_languages=['*'];options.name_legacy=True
        options.recalc_timestamp=False
        options.layout_features=['*']
        worker=subset.Subsetter(options=options)
        worker.populate(unicodes=sorted(kept))
        worker.subset(font)
    rename(font,license_body)
    OUT.mkdir(parents=True,exist_ok=True)
    font.save(str(output),reorderTables=True)
    font.close()
    (OUT/'LICENSE-OFL.txt').write_text(license_body,encoding='utf-8')
    (OUT/'characters.txt').write_text(''.join(chr(cp) for cp in sorted(required))+'\n',encoding='utf-8')
    info=verify_font(output,required)
    manifest={'output':output.name,'mode':'full-sc-layout' if args.full else 'ui-subset',
              'source_file':source.name,'source_sha256':sha(source),'face_index':index,
              'copyright_source_file':copyright_path.name,'copyright_source_sha256':sha(copyright_path),
              'original_names':source_names,'output_sha256':sha(output),'bytes':output.stat().st_size,
              'coverage':info,'scanned_sources':scanned}
    (OUT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({k:manifest[k] for k in ['mode','bytes','output_sha256','coverage']},ensure_ascii=False,indent=2))

if __name__=='__main__':main()
