from pathlib import Path
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.enums import TA_CENTER
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, PageBreak, Preformatted
from reportlab.lib.units import mm
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.pdfbase import pdfmetrics
from xml.sax.saxutils import escape
import mimetypes

ROOT = Path(".")
OUT = Path("exportacao/Ascensao_do_Soberano_fontes_completas.pdf")
OUT.parent.mkdir(exist_ok=True)
SKIP_DIRS = {".git", ".gradle", ".idea", "build", ".kotlin", "node_modules", ".firebase"}
SKIP_NAMES = {"google-services.json", "local.properties", ".env", ".env.local"}
SKIP_SUFFIXES = {".png", ".jpg", ".jpeg", ".webp", ".gif", ".mp4", ".mov", ".mp3", ".wav", ".aar", ".jar", ".apk", ".aab", ".keystore", ".jks", ".pdf", ".zip", ".gz", ".webm", ".ico"}
files = []
for p in ROOT.rglob("*"):
    if not p.is_file() or any(part in SKIP_DIRS for part in p.parts):
        continue
    if p.name in SKIP_NAMES or p.suffix.lower() in SKIP_SUFFIXES:
        continue
    if any(part.startswith(".") and part not in {".github"} for part in p.parts[:-1]):
        continue
    try:
        data = p.read_bytes()
        text = data.decode("utf-8")
        if "\x00" in text:
            continue
    except (UnicodeDecodeError, OSError):
        continue
    files.append((p.as_posix(), text))
files.sort(key=lambda x: x[0].lower())

styles = getSampleStyleSheet()
title = ParagraphStyle("CoverTitle", parent=styles["Title"], alignment=TA_CENTER, fontSize=22, leading=28, spaceAfter=18)
sub = ParagraphStyle("CoverSub", parent=styles["Normal"], alignment=TA_CENTER, fontSize=10, leading=15)
path_style = ParagraphStyle("Path", parent=styles["Heading2"], fontSize=10, leading=13, spaceAfter=6, wordWrap="CJK")
code_style = ParagraphStyle("Code", fontName="Courier", fontSize=6.4, leading=8, leftIndent=0, rightIndent=0, spaceAfter=0, splitLongWords=1)
story = [Spacer(1, 55*mm), Paragraph("ASCENSÃO DO SOBERANO", title), Paragraph("Compilação dos arquivos de texto do repositório", sub), Spacer(1, 8*mm), Paragraph(f"{len(files)} arquivos incluídos • cada arquivo começa em uma nova seção", sub), Paragraph("Arquivos binários, vídeos, imagens, pacotes e credenciais locais foram excluídos.", sub), PageBreak()]
for index, (name, content) in enumerate(files):
    story.append(Paragraph(escape(name), path_style))
    if not content:
        content = "[arquivo vazio]"
    # Preserve code exactly while wrapping long lines for page width.
    wrapped = []
    for line in content.splitlines():
        while len(line) > 150:
            wrapped.append(line[:150])
            line = line[150:]
        wrapped.append(line)
    story.append(Preformatted("\n".join(wrapped), code_style, maxLineLength=150))
    if index != len(files)-1:
        story.append(PageBreak())

def footer(canvas, doc):
    canvas.saveState()
    canvas.setFont("Helvetica", 8)
    canvas.drawString(18*mm, 10*mm, "Ascensão do Soberano • exportação de fontes")
    canvas.drawRightString(A4[0]-18*mm, 10*mm, f"Página {doc.page}")
    canvas.restoreState()

doc = SimpleDocTemplate(str(OUT), pagesize=A4, rightMargin=16*mm, leftMargin=16*mm, topMargin=16*mm, bottomMargin=17*mm, title="Ascensão do Soberano - Fontes completas")
doc.build(story, onFirstPage=footer, onLaterPages=footer)
print(f"PDF criado: {OUT} | arquivos: {len(files)} | tamanho: {OUT.stat().st_size} bytes")
