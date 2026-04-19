*&---------------------------------------------------------------------*
*& Report ZMM_PO_ANALYTICS_ALV
*&---------------------------------------------------------------------*
*& Purpose : Purchase Order Analytics and Vendor Overview.
*&           Reads standard SAP MM purchasing data and displays a
*&           consolidated ALV report with vendor details, material
*&           descriptions, delivery dates, and calculated status.
*& Author  : Ayush Singh (2305124)
*& Program : B.Tech CSE 2027
*& Created : April 2026
*& Tables  : EKKO, EKPO, LFA1, MAKT, EKET
*& UI      : CL_SALV_TABLE (ALV Object Model)
*&---------------------------------------------------------------------*
REPORT zmm_po_analytics_alv.

*----------------------------------------------------------------------*
*  Table Declarations for Selection Screen
*----------------------------------------------------------------------*
TABLES: ekko, ekpo.

*----------------------------------------------------------------------*
*  Selection Screen — Procurement Filters
*----------------------------------------------------------------------*
SELECT-OPTIONS:
  s_bukrs FOR ekko-bukrs,          " Company Code
  s_ekorg FOR ekko-ekorg,          " Purchasing Organization
  s_lifnr FOR ekko-lifnr,          " Vendor Number
  s_ebeln FOR ekko-ebeln,          " Purchase Order Number
  s_matnr FOR ekpo-matnr,          " Material Number
  s_bedat FOR ekko-bedat.          " PO Date Range

*----------------------------------------------------------------------*
*  Type Definitions
*----------------------------------------------------------------------*

* Main output structure for ALV display
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
         status TYPE char20,         " Calculated Delivery Status
         elikz  TYPE ekpo-elikz,     " Delivery Completed Indicator
         loekz  TYPE ekpo-loekz,     " Deletion Indicator
       END OF ty_output.

* Schedule line structure for delivery date lookup
TYPES: BEGIN OF ty_schedule,
         ebeln TYPE eket-ebeln,      " Purchase Order Number
         ebelp TYPE eket-ebelp,      " PO Item Number
         eindt TYPE eket-eindt,      " Delivery Date
       END OF ty_schedule.

*----------------------------------------------------------------------*
*  Forward Declaration for Event Handler Class
*----------------------------------------------------------------------*
CLASS lcl_event_handler DEFINITION DEFERRED.

*----------------------------------------------------------------------*
*  Global Data
*----------------------------------------------------------------------*
DATA:
  gt_output         TYPE STANDARD TABLE OF ty_output WITH DEFAULT KEY,
  go_salv           TYPE REF TO cl_salv_table,
  go_event_handler  TYPE REF TO lcl_event_handler.

*----------------------------------------------------------------------*
*  Local Class — ALV Event Handler
*----------------------------------------------------------------------*
CLASS lcl_event_handler DEFINITION.
  PUBLIC SECTION.
    "! Handles hotspot click on the PO Number column.
    "! Opens transaction ME23N (Display Purchase Order).
    METHODS on_link_click
      FOR EVENT link_click OF cl_salv_events_table
      IMPORTING row column.
ENDCLASS.

CLASS lcl_event_handler IMPLEMENTATION.
  METHOD on_link_click.
    DATA ls_output TYPE ty_output.

    " Only respond to clicks on the PO Number column
    CHECK column = 'EBELN'.

    " Read the clicked row from the output table
    READ TABLE gt_output INTO ls_output INDEX row.
    CHECK sy-subrc = 0.

    " Set parameter and navigate to PO display
    SET PARAMETER ID 'BES' FIELD ls_output-ebeln.
    CALL TRANSACTION 'ME23N' AND SKIP FIRST SCREEN.
  ENDMETHOD.
ENDCLASS.

*----------------------------------------------------------------------*
*  Main Processing Block
*----------------------------------------------------------------------*
START-OF-SELECTION.

  " Step 1: Fetch and prepare data
  PERFORM get_data.

  " Step 2: Handle empty result set
  IF gt_output IS INITIAL.
    MESSAGE 'No purchase orders found for the selected criteria.' TYPE 'S' DISPLAY LIKE 'I'.
    RETURN.
  ENDIF.

  " Step 3: Display ALV report
  PERFORM display_alv.


*&---------------------------------------------------------------------*
*& Form GET_DATA
*&---------------------------------------------------------------------*
*& Retrieves purchase order data by joining standard MM tables:
*&   EKKO (PO Header) + EKPO (PO Item) + LFA1 (Vendor) + MAKT (Material)
*& Then enriches with delivery dates from EKET and calculates status.
*&---------------------------------------------------------------------*
FORM get_data.

  " Main data extraction using Open SQL joins
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
    ekpo~meins,
    ekpo~netpr,
    ekpo~peinh,
    ekpo~netwr,
    ekko~waers,
    ekpo~elikz,
    ekpo~loekz
    FROM ekko
    INNER JOIN ekpo
      ON ekpo~ebeln = ekko~ebeln
    LEFT OUTER JOIN lfa1
      ON lfa1~lifnr = ekko~lifnr
    LEFT OUTER JOIN makt
      ON makt~matnr = ekpo~matnr
     AND makt~spras = @sy-langu
    INTO CORRESPONDING FIELDS OF TABLE @gt_output
    WHERE ekko~bukrs IN @s_bukrs
      AND ekko~ekorg IN @s_ekorg
      AND ekko~lifnr IN @s_lifnr
      AND ekko~ebeln IN @s_ebeln
      AND ekpo~matnr IN @s_matnr
      AND ekko~bedat IN @s_bedat.

  IF gt_output IS INITIAL.
    RETURN.
  ENDIF.

  " Enrich each item with earliest delivery date from EKET
  PERFORM enrich_delivery_dates.

  " Classify each item with a business-facing status
  PERFORM build_status_text.

  " Sort for consistent ALV display
  SORT gt_output BY ebeln ebelp.

ENDFORM.


*&---------------------------------------------------------------------*
*& Form ENRICH_DELIVERY_DATES
*&---------------------------------------------------------------------*
*& Reads schedule line data from EKET using FOR ALL ENTRIES.
*& Assigns the earliest delivery date to each item in gt_output.
*&---------------------------------------------------------------------*
FORM enrich_delivery_dates.
  DATA lt_schedule TYPE STANDARD TABLE OF ty_schedule WITH DEFAULT KEY.

  FIELD-SYMBOLS:
    <ls_output>   TYPE ty_output,
    <ls_schedule> TYPE ty_schedule.

  " Fetch schedule lines for all PO items
  SELECT ebeln, ebelp, eindt
    FROM eket
    INTO TABLE @lt_schedule
    FOR ALL ENTRIES IN @gt_output
    WHERE ebeln = @gt_output-ebeln
      AND ebelp = @gt_output-ebelp.

  IF sy-subrc <> 0.
    RETURN.
  ENDIF.

  " Sort and deduplicate to keep earliest date per item
  SORT lt_schedule BY ebeln ebelp eindt.
  DELETE ADJACENT DUPLICATES FROM lt_schedule COMPARING ebeln ebelp.

  " Assign dates using binary search for performance
  LOOP AT gt_output ASSIGNING <ls_output>.
    READ TABLE lt_schedule ASSIGNING <ls_schedule>
      WITH KEY ebeln = <ls_output>-ebeln
               ebelp = <ls_output>-ebelp
      BINARY SEARCH.
    IF sy-subrc = 0.
      <ls_output>-eindt = <ls_schedule>-eindt.
    ENDIF.
  ENDLOOP.

ENDFORM.


*&---------------------------------------------------------------------*
*& Form BUILD_STATUS_TEXT
*&---------------------------------------------------------------------*
*& Applies business rules to calculate delivery status per item:
*&   Deleted     → deletion indicator is set
*&   Completed   → delivery completed indicator set
*&   No Schedule → no schedule line exists
*&   Overdue     → delivery date has passed
*&   Due Soon    → delivery date within 7 days
*&   On Time     → delivery date more than 7 days away
*&---------------------------------------------------------------------*
FORM build_status_text.
  FIELD-SYMBOLS <ls_output> TYPE ty_output.

  DATA lv_due_soon TYPE sy-datum.

  " Due-soon boundary = today + 7 days
  lv_due_soon = sy-datum + 7.

  LOOP AT gt_output ASSIGNING <ls_output>.
    IF <ls_output>-loekz = 'L'.
      <ls_output>-status = 'Deleted'.
    ELSEIF <ls_output>-elikz = 'X'.
      <ls_output>-status = 'Completed'.
    ELSEIF <ls_output>-eindt IS INITIAL.
      <ls_output>-status = 'No Schedule'.
    ELSEIF <ls_output>-eindt < sy-datum.
      <ls_output>-status = 'Overdue'.
    ELSEIF <ls_output>-eindt <= lv_due_soon.
      <ls_output>-status = 'Due Soon'.
    ELSE.
      <ls_output>-status = 'On Time'.
    ENDIF.
  ENDLOOP.

ENDFORM.


*&---------------------------------------------------------------------*
*& Form DISPLAY_ALV
*&---------------------------------------------------------------------*
*& Creates and configures the ALV table using CL_SALV_TABLE.
*& Sets column texts, enables hotspot navigation on PO number,
*& applies striped pattern, and registers the event handler.
*&---------------------------------------------------------------------*
FORM display_alv.
  DATA:
    lo_columns  TYPE REF TO cl_salv_columns_table,
    lo_display  TYPE REF TO cl_salv_display_settings,
    lo_functions TYPE REF TO cl_salv_functions_list,
    lo_events   TYPE REF TO cl_salv_events_table.

  TRY.
      " Create ALV instance
      cl_salv_table=>factory(
        IMPORTING
          r_salv_table = go_salv
        CHANGING
          t_table      = gt_output ).

      " Auto-optimize column widths
      lo_columns = go_salv->get_columns( ).
      lo_columns->set_optimize( abap_true ).

      " Set report header and zebra pattern
      lo_display = go_salv->get_display_settings( ).
      lo_display->set_list_header( 'Purchase Order Analytics and Vendor Overview' ).
      lo_display->set_striped_pattern( abap_true ).

      " Enable all standard ALV toolbar functions
      lo_functions = go_salv->get_functions( ).
      lo_functions->set_all( abap_true ).

      " Apply business-friendly column headers
      PERFORM set_column_texts USING lo_columns.

      " Hide technical flag columns (ELIKZ, LOEKZ)
      PERFORM hide_technical_columns USING lo_columns.

      " Register event handler for PO hotspot clicks
      lo_events = go_salv->get_event( ).
      CREATE OBJECT go_event_handler.
      SET HANDLER go_event_handler->on_link_click FOR lo_events.

      " Render the ALV report
      go_salv->display( ).

    CATCH cx_salv_msg INTO DATA(lx_salv).
      MESSAGE lx_salv->get_text( ) TYPE 'S' DISPLAY LIKE 'E'.
  ENDTRY.

ENDFORM.


*&---------------------------------------------------------------------*
*& Form SET_COLUMN_TEXTS
*&---------------------------------------------------------------------*
*& Configures readable column headers for the ALV output.
*& Sets short, medium, and long text for each displayed column.
*& Configures PO Number column as a clickable hotspot.
*&---------------------------------------------------------------------*
FORM set_column_texts USING io_columns TYPE REF TO cl_salv_columns_table.
  DATA lo_column TYPE REF TO cl_salv_column_table.

  TRY.
      lo_column ?= io_columns->get_column( 'BUKRS' ).
      lo_column->set_medium_text( 'Company Code' ).
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
      lo_column->set_long_text( 'Purchase Order Item' ).

      lo_column ?= io_columns->get_column( 'BEDAT' ).
      lo_column->set_medium_text( 'PO Date' ).
      lo_column->set_long_text( 'Purchase Order Date' ).

      lo_column ?= io_columns->get_column( 'MATNR' ).
      lo_column->set_medium_text( 'Material' ).
      lo_column->set_long_text( 'Material Number' ).

      lo_column ?= io_columns->get_column( 'MAKTX' ).
      lo_column->set_medium_text( 'Material Text' ).
      lo_column->set_long_text( 'Material Description' ).

      lo_column ?= io_columns->get_column( 'WERKS' ).
      lo_column->set_medium_text( 'Plant' ).
      lo_column->set_long_text( 'Plant' ).

      lo_column ?= io_columns->get_column( 'MENGE' ).
      lo_column->set_medium_text( 'Order Qty' ).
      lo_column->set_long_text( 'Ordered Quantity' ).

      lo_column ?= io_columns->get_column( 'MEINS' ).
      lo_column->set_medium_text( 'UoM' ).
      lo_column->set_long_text( 'Unit of Measure' ).

      lo_column ?= io_columns->get_column( 'NETPR' ).
      lo_column->set_medium_text( 'Net Price' ).
      lo_column->set_long_text( 'Net Price' ).

      lo_column ?= io_columns->get_column( 'PEINH' ).
      lo_column->set_medium_text( 'Per' ).
      lo_column->set_long_text( 'Price Unit' ).

      lo_column ?= io_columns->get_column( 'NETWR' ).
      lo_column->set_medium_text( 'Net Value' ).
      lo_column->set_long_text( 'Net Order Value' ).

      lo_column ?= io_columns->get_column( 'WAERS' ).
      lo_column->set_medium_text( 'Curr.' ).
      lo_column->set_long_text( 'Currency' ).

      lo_column ?= io_columns->get_column( 'EINDT' ).
      lo_column->set_medium_text( 'Delv. Date' ).
      lo_column->set_long_text( 'Delivery Date' ).

      lo_column ?= io_columns->get_column( 'STATUS' ).
      lo_column->set_medium_text( 'Status' ).
      lo_column->set_long_text( 'Delivery Status' ).
    CATCH cx_salv_not_found.
  ENDTRY.

ENDFORM.


*&---------------------------------------------------------------------*
*& Form HIDE_TECHNICAL_COLUMNS
*&---------------------------------------------------------------------*
*& Hides internal flag columns from ALV display.
*& ELIKZ and LOEKZ are used for status calculation but should not
*& be visible to end users.
*&---------------------------------------------------------------------*
FORM hide_technical_columns USING io_columns TYPE REF TO cl_salv_columns_table.
  DATA lo_column TYPE REF TO cl_salv_column_table.

  TRY.
      lo_column ?= io_columns->get_column( 'ELIKZ' ).
      lo_column->set_visible( abap_false ).

      lo_column ?= io_columns->get_column( 'LOEKZ' ).
      lo_column->set_visible( abap_false ).
    CATCH cx_salv_not_found.
  ENDTRY.

ENDFORM.
