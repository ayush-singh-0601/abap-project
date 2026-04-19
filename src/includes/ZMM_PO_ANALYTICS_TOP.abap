*&---------------------------------------------------------------------*
*& Include           ZMM_PO_ANALYTICS_TOP
*&---------------------------------------------------------------------*
*& Purpose : Global type definitions, data declarations, and
*&           selection-screen parameters for the PO Analytics report.
*& Author  : Ayush Singh (2305124)
*& Created : April 2026
*&---------------------------------------------------------------------*

TABLES: ekko, ekpo.

*----------------------------------------------------------------------*
*  Selection Screen
*----------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-001.
  SELECT-OPTIONS:
    s_bukrs FOR ekko-bukrs,          " Company Code
    s_ekorg FOR ekko-ekorg,          " Purchasing Organization
    s_lifnr FOR ekko-lifnr,          " Vendor Number
    s_ebeln FOR ekko-ebeln,          " Purchase Order Number
    s_matnr FOR ekpo-matnr,          " Material Number
    s_bedat FOR ekko-bedat.          " PO Date
SELECTION-SCREEN END OF BLOCK b1.

*----------------------------------------------------------------------*
*  Type Definitions
*----------------------------------------------------------------------*

* Output structure for ALV display
TYPES: BEGIN OF ty_output,
         bukrs  TYPE ekko-bukrs,     " Company Code
         ekorg  TYPE ekko-ekorg,     " Purchasing Organization
         lifnr  TYPE ekko-lifnr,     " Vendor Number
         name1  TYPE lfa1-name1,     " Vendor Name
         ebeln  TYPE ekko-ebeln,     " Purchase Order Number
         ebelp  TYPE ekpo-ebelp,     " PO Item Number
         bedat  TYPE ekko-bedat,     " PO Date
         matnr  TYPE ekpo-matnr,     " Material Number
         maktx  TYPE makt-maktx,     " Material Description
         werks  TYPE ekpo-werks,     " Plant
         menge  TYPE ekpo-menge,     " Order Quantity
         meins  TYPE ekpo-meins,     " Unit of Measure
         netpr  TYPE ekpo-netpr,     " Net Price
         peinh  TYPE ekpo-peinh,     " Price Unit
         netwr  TYPE ekpo-netwr,     " Net Value
         waers  TYPE ekko-waers,     " Currency Key
         eindt  TYPE eket-eindt,     " Delivery Date
         status TYPE char20,         " Delivery Status Text
         elikz  TYPE ekpo-elikz,     " Delivery Completed Indicator
         loekz  TYPE ekpo-loekz,     " Deletion Indicator
       END OF ty_output.

* Schedule line structure for delivery date enrichment
TYPES: BEGIN OF ty_schedule,
         ebeln TYPE eket-ebeln,      " Purchase Order Number
         ebelp TYPE eket-ebelp,      " PO Item Number
         eindt TYPE eket-eindt,      " Delivery Date
       END OF ty_schedule.

* Vendor summary structure for scorecard analysis
TYPES: BEGIN OF ty_vendor_summary,
         lifnr       TYPE lfa1-lifnr,     " Vendor Number
         name1       TYPE lfa1-name1,     " Vendor Name
         total_pos   TYPE i,              " Total PO Count
         total_items TYPE i,              " Total Item Count
         total_value TYPE ekpo-netwr,     " Sum of Net Value
         waers       TYPE ekko-waers,     " Currency
         on_time     TYPE i,              " On-Time Item Count
         due_soon    TYPE i,              " Due-Soon Item Count
         overdue     TYPE i,              " Overdue Item Count
         completed   TYPE i,              " Completed Item Count
       END OF ty_vendor_summary.

*----------------------------------------------------------------------*
*  Constants
*----------------------------------------------------------------------*
CONSTANTS:
  gc_status_deleted     TYPE char20 VALUE 'Deleted',
  gc_status_completed   TYPE char20 VALUE 'Completed',
  gc_status_no_schedule TYPE char20 VALUE 'No Schedule',
  gc_status_overdue     TYPE char20 VALUE 'Overdue',
  gc_status_due_soon    TYPE char20 VALUE 'Due Soon',
  gc_status_on_time     TYPE char20 VALUE 'On Time',
  gc_due_soon_days      TYPE i      VALUE 7.

*----------------------------------------------------------------------*
*  Global Data
*----------------------------------------------------------------------*
DATA:
  gt_output         TYPE STANDARD TABLE OF ty_output WITH DEFAULT KEY,
  go_salv           TYPE REF TO cl_salv_table,
  go_event_handler  TYPE REF TO lcl_event_handler.
