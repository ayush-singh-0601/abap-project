*&---------------------------------------------------------------------*
*& Include           ZMM_PO_ANALYTICS_CL
*&---------------------------------------------------------------------*
*& Purpose : Local class definition and implementation for ALV event
*&           handling in the PO Analytics report.
*& Author  : Ayush Singh (2305124)
*& Created : April 2026
*&---------------------------------------------------------------------*

*----------------------------------------------------------------------*
*  Local Class Definition
*----------------------------------------------------------------------*
CLASS lcl_event_handler DEFINITION.
  PUBLIC SECTION.
    "! Handler for ALV hotspot link click events.
    "! Navigates to ME23N when the PO Number column is clicked.
    METHODS on_link_click
      FOR EVENT link_click OF cl_salv_events_table
      IMPORTING row column.

    "! Handler for ALV double-click events.
    "! Alternative navigation for PO drilldown.
    METHODS on_double_click
      FOR EVENT double_click OF cl_salv_events_table
      IMPORTING row column.
ENDCLASS.

*----------------------------------------------------------------------*
*  Local Class Implementation
*----------------------------------------------------------------------*
CLASS lcl_event_handler IMPLEMENTATION.

  METHOD on_link_click.
    DATA ls_output TYPE ty_output.

    " Only react to clicks on the PO Number column
    CHECK column = 'EBELN'.

    " Read the corresponding row from the output table
    READ TABLE gt_output INTO ls_output INDEX row.
    CHECK sy-subrc = 0.

    " Set the PO number parameter and navigate to ME23N
    SET PARAMETER ID 'BES' FIELD ls_output-ebeln.
    CALL TRANSACTION 'ME23N' AND SKIP FIRST SCREEN.
  ENDMETHOD.

  METHOD on_double_click.
    DATA ls_output TYPE ty_output.

    " On double click of vendor column, open vendor display
    CHECK column = 'LIFNR'.

    READ TABLE gt_output INTO ls_output INDEX row.
    CHECK sy-subrc = 0.

    " Navigate to vendor display XK03
    SET PARAMETER ID 'LIF' FIELD ls_output-lifnr.
    CALL TRANSACTION 'XK03' AND SKIP FIRST SCREEN.
  ENDMETHOD.

ENDCLASS.
