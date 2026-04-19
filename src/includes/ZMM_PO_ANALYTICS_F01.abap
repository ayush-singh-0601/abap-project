*&---------------------------------------------------------------------*
*& Include           ZMM_PO_ANALYTICS_F01
*&---------------------------------------------------------------------*
*& Purpose : Form routines (subroutines) for the PO Analytics report.
*&           Contains data retrieval, enrichment, status logic, and
*&           ALV display configuration.
*& Author  : Ayush Singh (2305124)
*& Created : April 2026
*&---------------------------------------------------------------------*

*&---------------------------------------------------------------------*
*& Form GET_DATA
*&---------------------------------------------------------------------*
*& Retrieves purchase order data by joining EKKO, EKPO, LFA1, and MAKT.
*& Applies user-entered selection screen filters. After initial fetch,
*& enriches delivery dates from EKET and calculates business status.
*&---------------------------------------------------------------------*
FORM get_data.

  " Main SELECT: join PO header, item, vendor master, and material text
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

  " Enrich with earliest delivery date from schedule lines
  PERFORM enrich_delivery_dates.

  " Apply business status logic to each item
  PERFORM build_status_text.

  " Sort for consistent display
  SORT gt_output BY ebeln ebelp.

ENDFORM.


*&---------------------------------------------------------------------*
*& Form ENRICH_DELIVERY_DATES
*&---------------------------------------------------------------------*
*& Reads schedule line data from EKET for all fetched PO items.
*& Assigns the earliest delivery date to each output record.
*&---------------------------------------------------------------------*
FORM enrich_delivery_dates.
  DATA lt_schedule TYPE STANDARD TABLE OF ty_schedule WITH DEFAULT KEY.

  FIELD-SYMBOLS:
    <ls_output>   TYPE ty_output,
    <ls_schedule> TYPE ty_schedule.

  " Fetch schedule lines for all PO items in the output
  SELECT ebeln, ebelp, eindt
    FROM eket
    INTO TABLE @lt_schedule
    FOR ALL ENTRIES IN @gt_output
    WHERE ebeln = @gt_output-ebeln
      AND ebelp = @gt_output-ebelp.

  IF sy-subrc <> 0.
    RETURN.
  ENDIF.

  " Keep only the earliest delivery date per PO item
  SORT lt_schedule BY ebeln ebelp eindt.
  DELETE ADJACENT DUPLICATES FROM lt_schedule COMPARING ebeln ebelp.

  " Assign delivery dates to output records using binary search
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
*& Applies business rules to determine delivery status for each item:
*&   Deleted     → deletion indicator is set
*&   Completed   → delivery completed indicator is set
*&   No Schedule → no schedule line exists
*&   Overdue     → delivery date is in the past
*&   Due Soon    → delivery date is within 7 days
*&   On Time     → delivery date is more than 7 days away
*&---------------------------------------------------------------------*
FORM build_status_text.
  FIELD-SYMBOLS <ls_output> TYPE ty_output.
  DATA lv_due_soon TYPE sy-datum.

  " Calculate the due-soon boundary date
  lv_due_soon = sy-datum + gc_due_soon_days.

  LOOP AT gt_output ASSIGNING <ls_output>.
    IF <ls_output>-loekz = 'L'.
      <ls_output>-status = gc_status_deleted.
    ELSEIF <ls_output>-elikz = 'X'.
      <ls_output>-status = gc_status_completed.
    ELSEIF <ls_output>-eindt IS INITIAL.
      <ls_output>-status = gc_status_no_schedule.
    ELSEIF <ls_output>-eindt < sy-datum.
      <ls_output>-status = gc_status_overdue.
    ELSEIF <ls_output>-eindt <= lv_due_soon.
      <ls_output>-status = gc_status_due_soon.
    ELSE.
      <ls_output>-status = gc_status_on_time.
    ENDIF.
  ENDLOOP.

ENDFORM.


*&---------------------------------------------------------------------*
*& Form DISPLAY_ALV
*&---------------------------------------------------------------------*
*& Creates and displays the ALV table using CL_SALV_TABLE.
*& Configures column texts, hotspot navigation, striped pattern,
*& standard ALV functions, and event handling.
*&---------------------------------------------------------------------*
FORM display_alv.
  DATA:
    lo_columns   TYPE REF TO cl_salv_columns_table,
    lo_display   TYPE REF TO cl_salv_display_settings,
    lo_functions TYPE REF TO cl_salv_functions_list,
    lo_events    TYPE REF TO cl_salv_events_table.

  TRY.
      " Create ALV instance from the output table
      cl_salv_table=>factory(
        IMPORTING
          r_salv_table = go_salv
        CHANGING
          t_table      = gt_output ).

      " Column settings: auto-width
      lo_columns = go_salv->get_columns( ).
      lo_columns->set_optimize( abap_true ).

      " Display settings: title and zebra striping
      lo_display = go_salv->get_display_settings( ).
      lo_display->set_list_header( 'Purchase Order Analytics and Vendor Overview' ).
      lo_display->set_striped_pattern( abap_true ).

      " Enable all standard ALV functions (sort, filter, export, etc.)
      lo_functions = go_salv->get_functions( ).
      lo_functions->set_all( abap_true ).

      " Set business-friendly column headers
      PERFORM set_column_texts USING lo_columns.

      " Hide technical flag columns from ALV output
      PERFORM hide_technical_columns USING lo_columns.

      " Register event handler for hotspot and double-click
      lo_events = go_salv->get_event( ).
      CREATE OBJECT go_event_handler.
      SET HANDLER go_event_handler->on_link_click FOR lo_events.
      SET HANDLER go_event_handler->on_double_click FOR lo_events.

      " Render ALV
      go_salv->display( ).

    CATCH cx_salv_msg INTO DATA(lx_salv).
      MESSAGE lx_salv->get_text( ) TYPE 'S' DISPLAY LIKE 'E'.
  ENDTRY.

ENDFORM.


*&---------------------------------------------------------------------*
*& Form SET_COLUMN_TEXTS
*&---------------------------------------------------------------------*
*& Assigns readable column headers (short, medium, long) to each field
*& in the ALV output. Also configures the PO number column as a hotspot.
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
*& Hides technical indicator fields (ELIKZ, LOEKZ) from ALV display.
*& These fields are used only for status calculation.
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
