from pathlib import Path

from pypdf import PdfReader, PdfWriter
from pypdf.annotations import Highlight
from pypdf.generic import ArrayObject, FloatObject


SOURCE = Path(r"D:\博一\气固相互作用\复合系数\main.pdf")
OUTPUT = Path(r"D:\博一\气固相互作用\202607_src\output\pdf\main_highlighted.pdf")


def quad(x1: float, y1: float, x2: float, y2: float) -> ArrayObject:
    # PDF highlight quad order: upper-left, upper-right, lower-left, lower-right.
    return ArrayObject(
        [
            FloatObject(x1),
            FloatObject(y2),
            FloatObject(x2),
            FloatObject(y2),
            FloatObject(x1),
            FloatObject(y1),
            FloatObject(x2),
            FloatObject(y1),
        ]
    )


reader = PdfReader(SOURCE)
writer = PdfWriter()
writer.clone_document_from_reader(reader)

# PDF page 6 (zero-based index 5), left-column paragraph describing the DS2V
# pairing algorithm and transfer of reaction energy to the surface.
page_index = 5
highlights = [
    # "DS2V carries out ... pre-stated probability ... unity and zero"
    (31.0, 513.0, 269.0, 548.0),
    # "When a molecule impacts ... same elemental area ... otherwise each
    # molecule leaves the surface separately."
    (31.0, 470.0, 269.0, 529.0),
    # "If a recombination reaction happens, all energy ... transferred to
    # the surface thus heat flux increases."
    (31.0, 420.0, 269.0, 462.0),
]

for x1, y1, x2, y2 in highlights:
    annotation = Highlight(
        rect=(x1, y1, x2, y2),
        quad_points=quad(x1, y1, x2, y2),
        highlight_color="ffff00",
        printing=True,
    )
    writer.add_annotation(page_number=page_index, annotation=annotation)

OUTPUT.parent.mkdir(parents=True, exist_ok=True)
with OUTPUT.open("wb") as stream:
    writer.write(stream)
