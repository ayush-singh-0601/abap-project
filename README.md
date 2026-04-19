# SAP ABAP MM (Purchase Order Analytics) Project

This project implements a complete SAP ABAP MM (Materials Management) reporting solution for procurement teams, providing comprehensive purchase order analytics, vendor scorecards, and delivery tracking.

## Project Structure

```text
src/
├── programs/
│   ├── ZMM_PO_ANALYTICS_ALV.abap     # Main PO Analytics Report
│   ├── ZMM_VENDOR_SCORECARD.abap     # Vendor Performance Scorecard Report
│   └── ZMM_PO_DELIVERY_TRACKER.abap  # Delivery Tracking Report
├── includes/
│   ├── ZMM_PO_ANALYTICS_TOP.abap     # Global declarations
│   ├── ZMM_PO_ANALYTICS_F01.abap     # FORM routines
│   └── ZMM_PO_ANALYTICS_CL.abap      # ALV display routines and events
├── docs/
│   ├── project-report.html           # Printable project report (A4 format)
│   └── project-report.pdf            # Generated PDF for submission
├── screenshots/                      # SAP screenshots and execution evidence
└── scripts/
    ├── create-submission-zip.ps1     # ZIP packaging script
    ├── generate-report-pdf.ps1       # PDF generation wrapper
    └── generate-report-pdf.py        # PDF generator (raw PDF builder)
```

## Key Features

### ZMM_PO_ANALYTICS_ALV - Main PO Analytics Report
- **Consolidated View**: PO header, item, vendor, and material data in one single place
- **Delivery Status**: Automatically calculated statuses (`Deleted`, `Completed`, `No Schedule`, `Overdue`, `Due Soon`, `On Time`)
- **Interactive Drilldown**: Hotspot navigation directly to PO display (`ME23N`) and Vendor display (`XK03`)

### ZMM_VENDOR_SCORECARD - Vendor Performance Scorecard
- **KPI Aggregation**: Totals for POs, line items, order value, and delivery status breakdown
- **On-Time Percentage**: Calculates vendor reliability metrics automatically
- **Value-Based Sorting**: Auto-sorts by total value to prioritize highest-impact vendors

### ZMM_PO_DELIVERY_TRACKER - Delivery Tracking Report
- **Dynamic Aging**: Days-remaining counter (displays negative numbers for overdue items)
- **Urgency Levels**: Classifies individual items as `HIGH`, `MEDIUM`, or `LOW` urgency
- **Detailed Filtering**: Show or hide specific status categories on demand

## Tech Stack
- **Language:** SAP ABAP
- **Module:** SAP MM (Materials Management — Purchasing)
- **Database Tables:** EKKO, EKPO, LFA1, MAKT, EKET
- **UI Framework:** CL_SALV_TABLE (ALV Object Model)
- **Documentation:** PowerShell + Python packaging scripts

## Submission Details

**Author** — Ayush Singh
**Roll No.** — 2305124
**Program** — B.Tech CSE 2027


