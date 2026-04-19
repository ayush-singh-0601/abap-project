*&---------------------------------------------------------------------*
*& Report ZMM_PO_DELIVERY_TRACKER
*&---------------------------------------------------------------------*
*& Purpose : Purchase Order Delivery Tracking Report.
*&           Displays PO items with delivery dates alongside a
*&           calculated "days remaining" or "days overdue" counter.
*&           Helps buyers quickly identify items that need follow-up.
*& Author  : Ayush Singh (2305124)
*& Created : April 2026
*& Tables  : EKKO, EKPO, LFA1, MAKT, EKET
*&---------------------------------------------------------------------*
REPORT zmm_po_delivery_tracker.

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
    s_bedat FOR ekko-bedat.          " PO Date Range
SELECTION-SCREEN END OF BLOCK b1.

SELECTION-SCREEN BEGIN OF BLOCK b2 WITH FRAME TITLE TEXT-002.
  PARAMETERS:
    p_overdu AS CHECKBOX DEFAULT 'X',  " Show overdue items
    p_dsoon  AS CHECKBOX DEFAULT 'X',  " Show due-soon items
    p_ontim  AS CHECKBOX DEFAULT 'X',  " Show on-time items
    p_days   TYPE i DEFAULT 7.         " Due-soon window (days)
SELECTION-SCREEN END OF BLOCK b2.

*----------------------------------------------------------------------*
*  Type Definitions
*----------------------------------------------------------------------*
TYPES: BEGIN OF ty_delivery,
         bukrs      TYPE ekko-bukrs,
         ekorg      TYPE ekko-ekorg,
         lifnr      TYPE ekko-lifnr,
         name1      TYPE lfa1-name1,
         ebeln      TYPE ekko-ebeln,
         ebelp      TYPE ekpo-ebelp,
         bedat      TYPE ekko-bedat,
         matnr      TYPE ekpo-matnr,
         maktx      TYPE makt-maktx,
         werks      TYPE ekpo-werks,
         menge      TYPE ekpo-menge,
         meins      TYPE ekpo-meins,
         eindt      TYPE eket-eindt,
         days_rem   TYPE i,
         status     TYPE char20,
         urgency    TYPE char10,
       END OF ty_delivery.

TYPES: BEGIN OF ty_schedule,
         ebeln TYPE eket-ebeln,
         ebelp TYPE eket-ebelp,
         eindt TYPE eket-eindt,
       END OF ty_schedule.

*----------------------------------------------------------------------*
*  Global Data
*----------------------------------------------------------------------*
DATA:
  gt_delivery TYPE STANDARD TABLE OF ty_delivery WITH DEFAULT KEY,
  go_salv     TYPE REF TO cl_salv_table.

*----------------------------------------------------------------------*
*  Event Handler for PO Drilldown
*----------------------------------------------------------------------*
CLASS lcl_events DEFINITION.
  PUBLIC SECTION.
    METHODS on_link_click
      FOR EVENT link_click OF cl_salv_events_table
      IMPORTING row column.
ENDCLASS.

CLASS lcl_events IMPLEMENTATION.
  METHOD on_link_click.
    DATA ls_row TYPE ty_delivery.
    CHECK column = 'EBELN'.
    READ TABLE gt_delivery INTO ls_row INDEX row.
    CHECK sy-subrc = 0.
    SET PARAMETER ID 'BES' FIELD ls_row-ebeln.
    CALL TRANSACTION 'ME23N' AND SKIP FIRST SCREEN.
  ENDMETHOD.
ENDCLASS.

DATA go_events TYPE REF TO lcl_events.

*----------------------------------------------------------------------*
*  Main Processing
*----------------------------------------------------------------------*
START-OF-SELECTION.
  PERFORM fetch_data.

  IF gt_delivery IS INITIAL.
    MESSAGE 'No delivery data found for the selected criteria.' TYPE 'S' DISPLAY LIKE 'I'.
    RETURN.
  ENDIF.

  PERFORM calculate_delivery_status.
  PERFORM filter_by_status.
  PERFORM display_tracker.


*&---------------------------------------------------------------------*
*& Form FETCH_DATA
*&---------------------------------------------------------------------*
*& Retrieves PO item data with vendor, material, and delivery dates.
*&---------------------------------------------------------------------*
FORM fetch_data.
  DATA lt_schedule TYPE STANDARD TABLE OF ty_schedule WITH DEFAULT KEY.
  FIELD-SYMBOLS:
    <ls_del>  TYPE ty_delivery,
    <ls_sch>  TYPE ty_schedule.

  " Fetch PO item data
  SELECT
    ekko~bukrs,
    ekko~ekorg,
    ekko~lifnr,
    lfa1~name1,
    ekko~ebeln,
    ekpo~ebelp,
    ekko~bedat,
    ekpo~matnr,
    makt~maktx,
    ekpo~werks,
    ekpo~menge,
    ekpo~meins
    FROM ekko
    INNER JOIN ekpo ON ekpo~ebeln = ekko~ebeln
    LEFT OUTER JOIN lfa1 ON lfa1~lifnr = ekko~lifnr
    LEFT OUTER JOIN makt
      ON makt~matnr = ekpo~matnr
     AND makt~spras = @sy-langu
    INTO CORRESPONDING FIELDS OF TABLE @gt_delivery
    WHERE ekko~bukrs IN @s_bukrs
      AND ekko~ekorg IN @s_ekorg
      AND ekko~lifnr IN @s_lifnr
      AND ekko~ebeln IN @s_ebeln
      AND ekpo~matnr IN @s_matnr
      AND ekko~bedat IN @s_bedat
      AND ekpo~loekz = @space            " Exclude deleted items
      AND ekpo~elikz = @space.           " Exclude completed items

  IF gt_delivery IS INITIAL.
    RETURN.
  ENDIF.

  " Enrich with delivery dates from EKET
  SELECT ebeln, ebelp, eindt
    FROM eket
    INTO TABLE @lt_schedule
    FOR ALL ENTRIES IN @gt_delivery
    WHERE ebeln = @gt_delivery-ebeln
      AND ebelp = @gt_delivery-ebelp.

  IF sy-subrc <> 0.
    RETURN.
  ENDIF.

  SORT lt_schedule BY ebeln ebelp eindt.
  DELETE ADJACENT DUPLICATES FROM lt_schedule COMPARING ebeln ebelp.

  LOOP AT gt_delivery ASSIGNING <ls_del>.
    READ TABLE lt_schedule ASSIGNING <ls_sch>
      WITH KEY ebeln = <ls_del>-ebeln
               ebelp = <ls_del>-ebelp
      BINARY SEARCH.
    IF sy-subrc = 0.
      <ls_del>-eindt = <ls_sch>-eindt.
    ENDIF.
  ENDLOOP.

  " Remove items with no delivery date
  DELETE gt_delivery WHERE eindt IS INITIAL.

ENDFORM.


*&---------------------------------------------------------------------*
*& Form CALCULATE_DELIVERY_STATUS
*&---------------------------------------------------------------------*
*& Calculates days remaining and urgency for each item.
*& Positive days_rem = days until delivery; negative = days overdue.
*&---------------------------------------------------------------------*
FORM calculate_delivery_status.
  FIELD-SYMBOLS <ls_del> TYPE ty_delivery.
  DATA lv_due_soon TYPE sy-datum.

  lv_due_soon = sy-datum + p_days.

  LOOP AT gt_delivery ASSIGNING <ls_del>.
    " Calculate days remaining (positive) or overdue (negative)
    <ls_del>-days_rem = <ls_del>-eindt - sy-datum.

    IF <ls_del>-eindt < sy-datum.
      <ls_del>-status  = 'Overdue'.
      <ls_del>-urgency = 'HIGH'.
    ELSEIF <ls_del>-eindt <= lv_due_soon.
      <ls_del>-status  = 'Due Soon'.
      <ls_del>-urgency = 'MEDIUM'.
    ELSE.
      <ls_del>-status  = 'On Time'.
      <ls_del>-urgency = 'LOW'.
    ENDIF.
  ENDLOOP.

  " Sort by urgency: overdue first, then due-soon, then on-time
  SORT gt_delivery BY days_rem ASCENDING.

ENDFORM.


*&---------------------------------------------------------------------*
*& Form FILTER_BY_STATUS
*&---------------------------------------------------------------------*
*& Applies user filter checkboxes to show/hide status categories.
*&---------------------------------------------------------------------*
FORM filter_by_status.

  IF p_overdu = space.
    DELETE gt_delivery WHERE status = 'Overdue'.
  ENDIF.

  IF p_dsoon = space.
    DELETE gt_delivery WHERE status = 'Due Soon'.
  ENDIF.

  IF p_ontim = space.
    DELETE gt_delivery WHERE status = 'On Time'.
  ENDIF.

ENDFORM.


*&---------------------------------------------------------------------*
*& Form DISPLAY_TRACKER
*&---------------------------------------------------------------------*
*& Displays the delivery tracker ALV with status-based display.
*&---------------------------------------------------------------------*
FORM display_tracker.
  DATA:
    lo_columns  TYPE REF TO cl_salv_columns_table,
    lo_display  TYPE REF TO cl_salv_display_settings,
    lo_functions TYPE REF TO cl_salv_functions_list,
    lo_events   TYPE REF TO cl_salv_events_table.

  TRY.
      cl_salv_table=>factory(
        IMPORTING
          r_salv_table = go_salv
        CHANGING
          t_table      = gt_delivery ).

      lo_columns = go_salv->get_columns( ).
      lo_columns->set_optimize( abap_true ).

      lo_display = go_salv->get_display_settings( ).
      lo_display->set_list_header( 'Purchase Order Delivery Tracker' ).
      lo_display->set_striped_pattern( abap_true ).

      lo_functions = go_salv->get_functions( ).
      lo_functions->set_all( abap_true ).

      PERFORM set_tracker_columns USING lo_columns.

      " Register PO drilldown event
      lo_events = go_salv->get_event( ).
      CREATE OBJECT go_events.
      SET HANDLER go_events->on_link_click FOR lo_events.

      go_salv->display( ).

    CATCH cx_salv_msg INTO DATA(lx_salv).
      MESSAGE lx_salv->get_text( ) TYPE 'S' DISPLAY LIKE 'E'.
  ENDTRY.

ENDFORM.


*&---------------------------------------------------------------------*
*& Form SET_TRACKER_COLUMNS
*&---------------------------------------------------------------------*
*& Configures column headers for the delivery tracker ALV.
*&---------------------------------------------------------------------*
FORM set_tracker_columns USING io_columns TYPE REF TO cl_salv_columns_table.
  DATA lo_column TYPE REF TO cl_salv_column_table.

  TRY.
      lo_column ?= io_columns->get_column( 'BUKRS' ).
      lo_column->set_medium_text( 'Co. Code' ).
      lo_column->set_long_text( 'Company Code' ).

      lo_column ?= io_columns->get_column( 'EKORG' ).
      lo_column->set_medium_text( 'Purch. Org' ).
      lo_column->set_long_text( 'Purchasing Organization' ).

      lo_column ?= io_columns->get_column( 'LIFNR' ).
      lo_column->set_medium_text( 'Vendor' ).
      lo_column->set_long_text( 'Vendor Number' ).

      lo_column ?= io_columns->get_column( 'NAME1' ).
      lo_column->set_medium_text( 'Vendor Name' ).
      lo_column->set_long_text( 'Vendor Name' ).

      lo_column ?= io_columns->get_column( 'EBELN' ).
      lo_column->set_short_text( 'PO' ).
      lo_column->set_medium_text( 'PO Number' ).
      lo_column->set_long_text( 'Purchase Order Number' ).
      lo_column->set_cell_type( if_salv_c_cell_type=>hotspot ).

      lo_column ?= io_columns->get_column( 'EBELP' ).
      lo_column->set_medium_text( 'Item' ).
      lo_column->set_long_text( 'PO Item' ).

      lo_column ?= io_columns->get_column( 'MATNR' ).
      lo_column->set_medium_text( 'Material' ).
      lo_column->set_long_text( 'Material Number' ).

      lo_column ?= io_columns->get_column( 'MAKTX' ).
      lo_column->set_medium_text( 'Description' ).
      lo_column->set_long_text( 'Material Description' ).

      lo_column ?= io_columns->get_column( 'WERKS' ).
      lo_column->set_medium_text( 'Plant' ).
      lo_column->set_long_text( 'Plant' ).

      lo_column ?= io_columns->get_column( 'MENGE' ).
      lo_column->set_medium_text( 'Qty' ).
      lo_column->set_long_text( 'Order Quantity' ).

      lo_column ?= io_columns->get_column( 'MEINS' ).
      lo_column->set_medium_text( 'UoM' ).
      lo_column->set_long_text( 'Unit of Measure' ).

      lo_column ?= io_columns->get_column( 'EINDT' ).
      lo_column->set_medium_text( 'Delv. Date' ).
      lo_column->set_long_text( 'Delivery Date' ).

      lo_column ?= io_columns->get_column( 'DAYS_REM' ).
      lo_column->set_medium_text( 'Days Left' ).
      lo_column->set_long_text( 'Days Remaining (negative = overdue)' ).

      lo_column ?= io_columns->get_column( 'STATUS' ).
      lo_column->set_medium_text( 'Status' ).
      lo_column->set_long_text( 'Delivery Status' ).

      lo_column ?= io_columns->get_column( 'URGENCY' ).
      lo_column->set_medium_text( 'Urgency' ).
      lo_column->set_long_text( 'Urgency Level' ).

      lo_column ?= io_columns->get_column( 'BEDAT' ).
      lo_column->set_medium_text( 'PO Date' ).
      lo_column->set_long_text( 'Purchase Order Date' ).

    CATCH cx_salv_not_found.
  ENDTRY.

ENDFORM.
