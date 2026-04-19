from __future__ import annotations

from pathlib import Path
import textwrap


PAGE_WIDTH = 595
PAGE_HEIGHT = 842
LEFT = 48
RIGHT = 48
TOP = 800
BOTTOM = 48
BODY_SIZE = 12
SUBHEADING_SIZE = 14
HEADING_SIZE = 15
MAX_WIDTH_CHARS = 92


def pdf_escape(text: str) -> str:
    return (
        text.replace("\\", "\\\\")
        .replace("(", "\\(")
        .replace(")", "\\)")
    )


class Page:
    def __init__(self) -> None:
        self.commands: list[str] = []
        self.y = TOP

    def text(self, x: float, y: float, text: str, font: str = "F1", size: int = BODY_SIZE) -> None:
        safe = pdf_escape(text)
        self.commands.append(f"BT /{font} {size} Tf 1 0 0 1 {x:.2f} {y:.2f} Tm ({safe}) Tj ET")

    def wrapped(self, text: str, x: float = LEFT, size: int = BODY_SIZE, font: str = "F1", gap: int = 16) -> None:
        for line in textwrap.wrap(text, width=MAX_WIDTH_CHARS):
            self.text(x, self.y, line, font=font, size=size)
            self.y -= gap
        self.y -= 4

    def heading(self, text: str) -> None:
        self.text(LEFT, self.y, text, font="F2", size=SUBHEADING_SIZE)
        self.y -= 22

    def bullet(self, text: str) -> None:
        wrapped = textwrap.wrap(text, width=MAX_WIDTH_CHARS - 4)
        if not wrapped:
            return
        self.text(LEFT + 2, self.y, "- " + wrapped[0], font="F1", size=BODY_SIZE)
        self.y -= 16
        for line in wrapped[1:]:
            self.text(LEFT + 14, self.y, line, font="F1", size=BODY_SIZE)
            self.y -= 16
        self.y -= 2

    def rect(self, x: float, y: float, w: float, h: float) -> None:
        self.commands.append(f"{x:.2f} {y:.2f} {w:.2f} {h:.2f} re S")

    def footer(self, page_number: int) -> None:
        self.text(PAGE_WIDTH - 90, 22, f"Page {page_number}", font="F1", size=11)

    def stream(self) -> bytes:
        return "\n".join(self.commands).encode("latin-1", errors="replace")


def build_pages() -> list[Page]:
    pages: list[Page] = []

    # ── Page 1 ─────────────────────────────────────────────────────────
    p1 = Page()
    title = "Purchase Order Analytics and Vendor Overview using Custom ALV Report"
    p1.text(78, p1.y, title, font="F2", size=HEADING_SIZE)
    p1.y -= 30
    p1.text(LEFT, p1.y, "Name: Ayush Singh", font="F2")
    p1.y -= 18
    p1.text(LEFT, p1.y, "Roll Number: 2305124", font="F2")
    p1.y -= 18
    p1.text(LEFT, p1.y, "Batch/Program: B.Tech CSE 2027", font="F2")
    p1.y -= 18
    p1.text(LEFT, p1.y, "Project Topic: Real ABAP Development Scenario - Custom ALV Reports", font="F2")
    p1.y -= 28
    p1.heading("Problem Statement")
    p1.wrapped(
        "In SAP MM environments, procurement users often need to open multiple transactions to review purchase order "
        "details, vendor information, material descriptions, delivery timelines, and item values. This slows daily work "
        "and makes it harder to identify delayed or urgent orders quickly."
    )
    p1.wrapped(
        "The business need is to create consolidated reports where buyers and procurement coordinators can review all "
        "critical purchasing information in a single screen and take follow-up action faster."
    )
    p1.heading("Project Objective")
    p1.wrapped(
        "The objective of this project is to build a suite of executable ABAP reports centered on ZMM_PO_ANALYTICS_ALV "
        "that read standard MM purchasing data, display them in ALV outputs with useful filters, calculated delivery "
        "status, drilldown support, vendor performance metrics, and delivery tracking."
    )
    p1.heading("Project Summary")
    p1.wrapped(
        "This capstone project focuses on practical MM reporting scenarios. It includes a main PO analytics report, "
        "a vendor performance scorecard, and a delivery tracking tool. The codebase demonstrates common ABAP skills "
        "such as selection-screen design, Open SQL joins, internal-table processing, ALV display handling, local "
        "class-based event handling, and business-rule implementation while keeping the scope manageable."
    )
    p1.footer(1)
    pages.append(p1)

    # ── Page 2 ─────────────────────────────────────────────────────────
    p2 = Page()
    p2.heading("Solution / Features")
    for item in [
        "Selection screen filters for company code, purchasing organization, vendor, PO number, material, and PO date.",
        "Data extraction from EKKO, EKPO, LFA1, MAKT, and EKET using Open SQL joins.",
        "ALV output showing vendor, material, quantity, value, delivery date, and item-level status.",
        "Status calculation: Deleted, Completed, No Schedule, Overdue, Due Soon, and On Time.",
        "Hotspot click on PO number to open ME23N; double-click on vendor to open XK03.",
        "Vendor performance scorecard with total POs, total value, and on-time delivery percentage.",
        "Delivery tracker with days-remaining counter, urgency levels, and status-based filtering.",
        "Modular code design with include programs (TOP, F01, CL) following ABAP conventions.",
    ]:
        p2.bullet(item)
    p2.heading("Tech Stack")
    for item in [
        "SAP ABAP",
        "SAP MM purchasing data model (EKKO, EKPO, LFA1, MAKT, EKET)",
        "CL_SALV_TABLE for ALV output (ALV Object Model)",
        "Modular programming with include programs",
        "Git and GitHub for repository hosting",
    ]:
        p2.bullet(item)
    p2.heading("ABAP Programs")
    p2.wrapped("The project consists of 6 ABAP programs: 3 executable reports and 3 include programs.")
    for item in [
        "ZMM_PO_ANALYTICS_ALV - Main PO Analytics Report with vendor and delivery details.",
        "ZMM_PO_ANALYTICS_TOP - Include: type definitions, constants, selection screen, global data.",
        "ZMM_PO_ANALYTICS_F01 - Include: form routines for data retrieval, status logic, ALV config.",
        "ZMM_PO_ANALYTICS_CL  - Include: local class for hotspot and double-click event handling.",
        "ZMM_VENDOR_SCORECARD  - Vendor performance scorecard with on-time delivery percentage.",
        "ZMM_PO_DELIVERY_TRACKER - Delivery tracking with days remaining and urgency levels.",
    ]:
        p2.bullet(item)
    p2.footer(2)
    pages.append(p2)

    # ── Page 3 ─────────────────────────────────────────────────────────
    p3 = Page()
    p3.heading("Data Flow and Business Logic")
    p3.wrapped(
        "The user enters filter values on the selection screen. The report reads purchase order data from EKKO and "
        "EKPO, vendor information from LFA1, material descriptions from MAKT, and schedule line dates from EKET. The "
        "program enriches the dataset in internal tables and prepares it for ALV display."
    )
    p3.wrapped(
        "Status logic is applied item by item. If the deletion indicator is set, the report shows Deleted. If delivery "
        "is completed, it shows Completed. If no schedule line exists, it shows No Schedule. Otherwise the delivery "
        "date is compared with the current system date to determine Overdue, Due Soon, or On Time."
    )
    p3.wrapped(
        "The vendor scorecard aggregates item-level data by vendor number, counting distinct POs, summing net values, "
        "and computing on-time delivery percentages. The delivery tracker calculates days remaining until delivery "
        "(negative values indicate overdue) and assigns urgency levels for quick prioritization."
    )
    p3.heading("Unique Points")
    for item in [
        "Balanced complexity for an ABAP capstone: practical, working, and explainable.",
        "Three complementary reports covering analytics, vendor scoring, and delivery tracking.",
        "Modular code design with separate include programs following ABAP conventions.",
        "Uses standard SAP MM tables so results can be validated easily in a training system.",
        "Combines reporting, aggregation, event handling, and business status calculation.",
    ]:
        p3.bullet(item)
    p3.heading("Why This Topic Fits an ABAP Developer")
    p3.wrapped(
        "This project directly reflects day-to-day ABAP enhancement work. It demonstrates selection-screen design, "
        "Open SQL joins, internal table processing, ALV formatting, local class event handling, and business rule "
        "implementation. The multi-report approach shows the ability to work across related tools within the same "
        "functional domain while avoiding unnecessary complexity."
    )
    p3.footer(3)
    pages.append(p3)

    # ── Page 4 ─────────────────────────────────────────────────────────
    p4 = Page()
    p4.heading("Screenshots")
    p4.wrapped(
        "Replace these placeholders with actual screenshots from your SAP system before final submission."
    )
    box_y = 620
    for label in [
        "Selection Screen Screenshot Placeholder",
        "ALV Output Screenshot Placeholder",
        "PO Drilldown Screenshot Placeholder",
    ]:
        p4.rect(LEFT, box_y, PAGE_WIDTH - LEFT - RIGHT, 150)
        p4.text(150, box_y + 74, label, font="F2")
        box_y -= 180
    p4.footer(4)
    pages.append(p4)

    # ── Page 5 ─────────────────────────────────────────────────────────
    p5 = Page()
    p5.heading("Future Improvements")
    for item in [
        "Add traffic-light icons and color-based status indicators.",
        "Add vendor-wise and plant-wise subtotals.",
        "Add authorization-based filtering using purchasing organization rules.",
        "Add Excel-friendly export customization.",
        "Add saved ALV layouts and variants.",
        "Integrate goods receipt data for three-way match analysis.",
    ]:
        p5.bullet(item)
    p5.heading("Conclusion")
    p5.wrapped(
        "This project provides a practical SAP MM reporting solution developed with standard ABAP techniques. The "
        "combination of a detailed PO analytics report, a vendor performance scorecard, and a delivery tracking tool "
        "demonstrates well-rounded ABAP development skills suitable for real-world SAP support and enhancement work."
    )
    p5.wrapped(
        "The modular code structure with include programs follows professional ABAP conventions and makes the codebase "
        "maintainable and easy to extend. Before final submission, replace placeholder screenshot areas with real values "
        "from your SAP environment."
    )
    p5.heading("Submission Details")
    for item in [
        "Student: Ayush Singh | Roll Number: 2305124 | Program: B.Tech CSE 2027",
        "ABAP Programs: 6 (3 reports + 3 includes)",
        "SAP Tables: EKKO, EKPO, LFA1, MAKT, EKET",
        "GitHub repository is public and accessible.",
    ]:
        p5.bullet(item)
    p5.footer(5)
    pages.append(p5)

    return pages


def build_pdf_bytes(pages: list[Page]) -> bytes:
    # Note: Using Helvetica as the PDF Type1 font.
    # Helvetica is the standard PDF equivalent of Arial and is
    # universally accepted as Arial's substitute in PDF documents.
    objects: list[bytes | None] = [None]

    def add_object(data: bytes) -> int:
        objects.append(data)
        return len(objects) - 1

    font_regular = add_object(b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>")
    font_bold = add_object(b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold >>")

    page_refs: list[int] = []
    content_refs: list[int] = []

    for page in pages:
        stream = page.stream()
        content_ref = add_object(
            b"<< /Length " + str(len(stream)).encode("ascii") + b" >>\nstream\n" + stream + b"\nendstream"
        )
        content_refs.append(content_ref)
        page_refs.append(0)

    pages_ref = add_object(b"")

    for index, content_ref in enumerate(content_refs):
        page_obj = (
            f"<< /Type /Page /Parent {pages_ref} 0 R /MediaBox [0 0 {PAGE_WIDTH} {PAGE_HEIGHT}] "
            f"/Resources << /Font << /F1 {font_regular} 0 R /F2 {font_bold} 0 R >> >> "
            f"/Contents {content_ref} 0 R >>"
        ).encode("ascii")
        page_refs[index] = add_object(page_obj)

    kids = " ".join(f"{ref} 0 R" for ref in page_refs)
    objects[pages_ref] = f"<< /Type /Pages /Count {len(page_refs)} /Kids [{kids}] >>".encode("ascii")

    catalog_ref = add_object(f"<< /Type /Catalog /Pages {pages_ref} 0 R >>".encode("ascii"))

    pdf = bytearray(b"%PDF-1.4\n%\xe2\xe3\xcf\xd3\n")
    offsets = [0]

    for obj_id in range(1, len(objects)):
        offsets.append(len(pdf))
        pdf.extend(f"{obj_id} 0 obj\n".encode("ascii"))
        pdf.extend(objects[obj_id] or b"")
        pdf.extend(b"\nendobj\n")

    xref_start = len(pdf)
    pdf.extend(f"xref\n0 {len(objects)}\n".encode("ascii"))
    pdf.extend(b"0000000000 65535 f \n")
    for offset in offsets[1:]:
        pdf.extend(f"{offset:010d} 00000 n \n".encode("ascii"))

    pdf.extend(
        f"trailer\n<< /Size {len(objects)} /Root {catalog_ref} 0 R >>\nstartxref\n{xref_start}\n%%EOF\n".encode(
            "ascii"
        )
    )
    return bytes(pdf)


def main() -> None:
    root = Path(__file__).resolve().parent.parent
    dist_dir = root / "dist"
    docs_dir = root / "docs"
    dist_dir.mkdir(exist_ok=True)
    docs_dir.mkdir(exist_ok=True)

    pdf_bytes = build_pdf_bytes(build_pages())

    dist_output = dist_dir / "project-report.pdf"
    docs_output = docs_dir / "project-report.pdf"

    dist_output.write_bytes(pdf_bytes)
    docs_output.write_bytes(pdf_bytes)

    print(f"PDF generated at: {dist_output}")
    print(f"PDF copied to: {docs_output}")


if __name__ == "__main__":
    main()
