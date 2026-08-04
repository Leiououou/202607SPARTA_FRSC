from pathlib import Path

from pypdf import PdfReader, PdfWriter


source_dir = Path(r"C:\Users\DELL\OneDrive\Desktop\家教")
output_dir = Path(r"D:\博一\气固相互作用\202607_src\output\pdf")

all_sources = [
    source_dir / "专题五答案.pdf",
    source_dir / "专题五巧选参考系.pdf",
    source_dir / "专题16答案.pdf",
    source_dir / "专题16非惯性系.pdf",
]
no_answer_sources = [
    source_dir / "专题五巧选参考系.pdf",
    source_dir / "专题16非惯性系.pdf",
]


def merge(sources: list[Path], destination: Path) -> None:
    writer = PdfWriter()
    for source in sources:
        reader = PdfReader(source)
        for page in reader.pages:
            writer.add_page(page)
    with destination.open("wb") as stream:
        writer.write(stream)


output_dir.mkdir(parents=True, exist_ok=True)
merge(all_sources, output_dir / "专题16与专题五_含答案.pdf")
merge(no_answer_sources, output_dir / "专题16与专题五_无答案.pdf")
