"""Build the offline poetry font. Usage: python subset-poetry-font.py SOURCE.ttf

Requires fonttools. The full upstream font is not needed to build the app.
Includes basic CJK, common punctuation and Latin; editable text keeps the system font.
"""
from pathlib import Path
import hashlib
import sys
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont
from fontTools import subset

source = Path(sys.argv[1])
root = Path(__file__).resolve().parents[1]
destination = root / "Sanju/Fonts"
destination.mkdir(exist_ok=True)
font = instantiateVariableFont(TTFont(source), {"wght": 400}, inplace=True)
options = subset.Options()
options.name_IDs = ["*"]
options.name_legacy = True
options.name_languages = ["*"]
subsetter = subset.Subsetter(options=options)
subsetter.populate(unicodes=list(range(0x20, 0x250)) + list(range(0x2000, 0x2070))
                   + list(range(0x3000, 0x3100)) + list(range(0x4E00, 0xA000))
                   + list(range(0xFF00, 0xFFF0)))
subsetter.subset(font)
names = {1: "Sanju Poetry", 2: "Regular", 3: "SanjuPoetry-Regular-1", 4: "Sanju Poetry Regular", 6: "SanjuPoetry-Regular", 16: "Sanju Poetry", 17: "Regular", 25: "SanjuPoetry"}
for record in font["name"].names:
    if record.nameID in names:
        record.string = names[record.nameID].encode(record.getEncoding())
font.save(destination / "SanjuPoetry-Regular.ttf")
print("Source SHA-256:", hashlib.sha256(source.read_bytes()).hexdigest())
print("Subset bytes:", (destination / "SanjuPoetry-Regular.ttf").stat().st_size)
