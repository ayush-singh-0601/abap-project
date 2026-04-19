*&---------------------------------------------------------------------*
*& Report ZMM_VENDOR_SCORECARD
*&---------------------------------------------------------------------*
*& Purpose : Vendor Performance Scorecard for MM Purchasing.
*&           Aggregates purchase order data by vendor and calculates
*&           key performance indicators such as total PO count, total
*&           order value, on-time delivery rate, and overdue items.
*& Author  : Ayush Singh (2305124)
*& Created : April 2026
*& Tables  : EKKO, EKPO, LFA1, EKET
*&---------------------------------------------------------------------*
REPORT zmm_vendor_scorecard.

TABLES: ekko, ekpo.

*----------------------------------------------------------------------*
*  Selection Screen
*----------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-001.
  SELECT-OPTIONS:
    s_bukrs FOR ekko-bukrs,          " Company Code
    s_ekorg FOR ekko-ekorg,          " Purchasing Organization
    s_lifnr FOR ekko-lifnr,          " Vendor Number
    s_bedat FOR ekko-bedat.          " PO Date Range
SELECTION-SCREEN END OF BLOCK b1.

*----------------------------------------------------------------------*
*  Type Definitions
*----------------------------------------------------------------------*
TYPES: BEGIN OF ty_po_item,
         bukrs TYPE ekko-bukrs,
         ekorg TYPE ekko-ekorg,
         lifnr TYPE ekko-lifnr,
         name1 TYPE lfa1-name1,
         ebeln TYPE ekko-ebeln,
         ebelp TYPE ekpo-ebelp,
         netwr TYPE ekpo-netwr,
         waers TYPE ekko-waers,
         eindt TYPE eket-eindt,
         elikz TYPE ekpo-elikz,
         loekz TYPE ekpo-loekz,
       END OF ty_po_item.

TYPES: BEGIN OF ty_scorecard,
         lifnr           TYPE lfa1-lifnr,
         name1           TYPE lfa1-name1,
         total_pos       TYPE i,
         total_items     TYPE i,
         total_value     TYPE p LENGTH 15 DECIMALS 2,
         waers           TYPE ekko-waers,
         on_time_count   TYPE i,
         due_soon_count  TYPE i,
         overdue_count   TYPE i,
         completed_count TYPE i,
         deleted_count   TYPE i,
         on_time_pct     TYPE p LENGTH 5 DECIMALS 1,
       END OF ty_scorecard.

TYPES: BEGIN OF ty_schedule,
         ebeln TYPE eket-ebeln,
         ebelp TYPE eket-ebelp,
         eindt TYPE eket-eindt,
       END OF ty_schedule.

*----------------------------------------------------------------------*
*  Global Data
*----------------------------------------------------------------------*
DATA:
  gt_items     TYPE STANDARD TABLE OF ty_po_item     WITH DEFAULT KEY,
  gt_scorecard TYPE STANDARD TABLE OF ty_scorecard   WITH DEFAULT KEY,
  go_salv      TYPE REF TO cl_salv_table.

*----------------------------------------------------------------------*
*  Main Processing
*----------------------------------------------------------------------*
START-OF-SELECTION.
  PERFORM fetch_po_data.

  IF gt_items IS INITIAL.
    MESSAGE 'No purchase order data found for the selected criteria.' TYPE 'S' DISPLAY LIKE 'I'.
    RETURN.
  ENDIF.

  PERFORM enrich_delivery_dates.
  PERFORM build_scorecard.
  PERFORM display_scorecard.


*&---------------------------------------------------------------------*
*& Form FETCH_PO_DATA
*&---------------------------------------------------------------------*
*& Fetches PO header and item data with vendor details.
*&---------------------------------------------------------------------*
FORM fetch_po_data.

  SELECT
    ekko~bukrs,
    ekko~ekorg,
    ekko~lifnr,
    lfa1~name1,
    ekko~ebeln,
    ekpo~ebelp,
    ekpo~netwr,
    ekko~waers,
    ekpo~elikz,
    ekpo~loekz
    FROM ekko
    INNER JOIN ekpo ON ekpo~ebeln = ekko~ebeln
    LEFT OUTER JOIN lfa1 ON lfa1~lifnr = ekko~lifnr
    INTO CORRESPONDING FIELDS OF TABLE @gt_items
    WHERE ekko~bukrs IN @s_bukrs
      AND ekko~ekorg IN @s_ekorg
      AND ekko~lifnr IN @s_lifnr
      AND ekko~bedat IN @s_bedat.

ENDFORM.


*&---------------------------------------------------------------------*
*& Form ENRICH_DELIVERY_DATES
*&---------------------------------------------------------------------*
*& Reads earliest schedule line delivery dates from EKET.
*&---------------------------------------------------------------------*
FORM enrich_delivery_dates.
  DATA lt_schedule TYPE STANDARD TABLE OF ty_schedule WITH DEFAULT KEY.

  FIELD-SYMBOLS:
    <ls_item>     TYPE ty_po_item,
    <ls_schedule> TYPE ty_schedule.

  SELECT ebeln, ebelp, eindt
    FROM eket
    INTO TABLE @lt_schedule
    FOR ALL ENTRIES IN @gt_items
    WHERE ebeln = @gt_items-ebeln
      AND ebelp = @gt_items-ebelp.

  IF sy-subrc <> 0.
    RETURN.
  ENDIF.

  SORT lt_schedule BY ebeln ebelp eindt.
  DELETE ADJACENT DUPLICATES FROM lt_schedule COMPARING ebeln ebelp.

  LOOP AT gt_items ASSIGNING <ls_item>.
    READ TABLE lt_schedule ASSIGNING <ls_schedule>
      WITH KEY ebeln = <ls_item>-ebeln
               ebelp = <ls_item>-ebelp
      BINARY SEARCH.
    IF sy-subrc = 0.
      <ls_item>-eindt = <ls_schedule>-eindt.
    ENDIF.
  ENDLOOP.

ENDFORM.


*&---------------------------------------------------------------------*
*& Form BUILD_SCORECARD
*&---------------------------------------------------------------------*
*& Aggregates PO item data by vendor and calculates KPIs:
*& total POs, total items, total value, status counts, on-time %.
*&---------------------------------------------------------------------*
FORM build_scorecard.
  DATA:
    ls_scorecard TYPE ty_scorecard,
    lv_due_soon  TYPE sy-datum.

  FIELD-SYMBOLS <ls_item> TYPE ty_po_item.

  lv_due_soon = sy-datum + 7.

  " Sort by vendor for aggregation
  SORT gt_items BY lifnr ebeln ebelp.

  DATA lv_prev_vendor TYPE lfa1-lifnr.
  DATA lv_prev_po     TYPE ekko-ebeln.

  LOOP AT gt_items ASSIGNING <ls_item>.

    " Detect vendor change → save previous scorecard
    IF lv_prev_vendor IS NOT INITIAL AND <ls_item>-lifnr <> lv_prev_vendor.
      " Calculate on-time percentage
      IF ls_scorecard-total_items > 0.
        ls_scorecard-on_time_pct =
          ( ls_scorecard-on_time_count + ls_scorecard-completed_count ) * 100
          / ls_scorecard-total_items.
      ENDIF.
      APPEND ls_scorecard TO gt_scorecard.
      CLEAR ls_scorecard.
      CLEAR lv_prev_po.
    ENDIF.

    " Initialize vendor in scorecard
    IF ls_scorecard-lifnr IS INITIAL.
      ls_scorecard-lifnr = <ls_item>-lifnr.
      ls_scorecard-name1 = <ls_item>-name1.
      ls_scorecard-waers = <ls_item>-waers.
    ENDIF.

    " Count distinct POs
    IF <ls_item>-ebeln <> lv_prev_po.
      ls_scorecard-total_pos = ls_scorecard-total_pos + 1.
      lv_prev_po = <ls_item>-ebeln.
    ENDIF.

    " Accumulate item-level metrics
    ls_scorecard-total_items = ls_scorecard-total_items + 1.
    ls_scorecard-total_value = ls_scorecard-total_value + <ls_item>-netwr.

    " Classify item status
    IF <ls_item>-loekz = 'L'.
      ls_scorecard-deleted_count = ls_scorecard-deleted_count + 1.
    ELSEIF <ls_item>-elikz = 'X'.
      ls_scorecard-completed_count = ls_scorecard-completed_count + 1.
    ELSEIF <ls_item>-eindt IS INITIAL.
      " No schedule — not counted in delivery KPIs
    ELSEIF <ls_item>-eindt < sy-datum.
      ls_scorecard-overdue_count = ls_scorecard-overdue_count + 1.
    ELSEIF <ls_item>-eindt <= lv_due_soon.
      ls_scorecard-due_soon_count = ls_scorecard-due_soon_count + 1.
    ELSE.
      ls_scorecard-on_time_count = ls_scorecard-on_time_count + 1.
    ENDIF.

    lv_prev_vendor = <ls_item>-lifnr.
  ENDLOOP.

  " Append last vendor scorecard
  IF ls_scorecard-lifnr IS NOT INITIAL.
    IF ls_scorecard-total_items > 0.
      ls_scorecard-on_time_pct =
        ( ls_scorecard-on_time_count + ls_scorecard-completed_count ) * 100
        / ls_scorecard-total_items.
    ENDIF.
    APPEND ls_scorecard TO gt_scorecard.
  ENDIF.

  " Sort by total value descending for top vendors first
  SORT gt_scorecard BY total_value DESCENDING.

ENDFORM.


*&---------------------------------------------------------------------*
*& Form DISPLAY_SCORECARD
*&---------------------------------------------------------------------*
*& Displays the vendor scorecard in ALV format.
*&---------------------------------------------------------------------*
FORM display_scorecard.
  DATA:
    lo_columns  TYPE REF TO cl_salv_columns_table,
    lo_display  TYPE REF TO cl_salv_display_settings,
    lo_functions TYPE REF TO cl_salv_functions_list.

  TRY.
      cl_salv_table=>factory(
        IMPORTING
          r_salv_table = go_salv
        CHANGING
          t_table      = gt_scorecard ).

      lo_columns = go_salv->get_columns( ).
      lo_columns->set_optimize( abap_true ).

      lo_display = go_salv->get_display_settings( ).
      lo_display->set_list_header( 'Vendor Performance Scorecard — Purchase Order Analysis' ).
      lo_display->set_striped_pattern( abap_true ).

      lo_functions = go_salv->get_functions( ).
      lo_functions->set_all( abap_true ).

      " Set readable column texts
      PERFORM set_scorecard_columns USING lo_columns.

      go_salv->display( ).

    CATCH cx_salv_msg INTO DATA(lx_salv).
      MESSAGE lx_salv->get_text( ) TYPE 'S' DISPLAY LIKE 'E'.
  ENDTRY.

ENDFORM.


*&---------------------------------------------------------------------*
*& Form SET_SCORECARD_COLUMNS
*&---------------------------------------------------------------------*
*& Column text configuration for scorecard ALV.
*&---------------------------------------------------------------------*
FORM set_scorecard_columns USING io_columns TYPE REF TO cl_salv_columns_table.
  DATA lo_column TYPE REF TO cl_salv_column_table.

  TRY.
      lo_column ?= io_columns->get_column( 'LIFNR' ).
      lo_column->set_medium_text( 'Vendor' ).
      lo_column->set_long_text( 'Vendor Number' ).

      lo_column ?= io_columns->get_column( 'NAME1' ).
      lo_column->set_medium_text( 'Vendor Name' ).
      lo_column->set_long_text( 'Vendor Name' ).

      lo_column ?= io_columns->get_column( 'TOTAL_POS' ).
      lo_column->set_medium_text( 'Total POs' ).
      lo_column->set_long_text( 'Total Purchase Orders' ).

      lo_column ?= io_columns->get_column( 'TOTAL_ITEMS' ).
      lo_column->set_medium_text( 'Total Items' ).
      lo_column->set_long_text( 'Total PO Line Items' ).

      lo_column ?= io_columns->get_column( 'TOTAL_VALUE' ).
      lo_column->set_medium_text( 'Total Value' ).
      lo_column->set_long_text( 'Total Net Order Value' ).

      lo_column ?= io_columns->get_column( 'WAERS' ).
      lo_column->set_medium_text( 'Curr.' ).
      lo_column->set_long_text( 'Currency' ).

      lo_column ?= io_columns->get_column( 'ON_TIME_COUNT' ).
      lo_column->set_medium_text( 'On Time' ).
      lo_column->set_long_text( 'On-Time Items' ).

      lo_column ?= io_columns->get_column( 'DUE_SOON_COUNT' ).
      lo_column->set_medium_text( 'Due Soon' ).
      lo_column->set_long_text( 'Due-Soon Items' ).

      lo_column ?= io_columns->get_column( 'OVERDUE_COUNT' ).
      lo_column->set_medium_text( 'Overdue' ).
      lo_column->set_long_text( 'Overdue Items' ).

      lo_column ?= io_columns->get_column( 'COMPLETED_COUNT' ).
      lo_column->set_medium_text( 'Completed' ).
      lo_column->set_long_text( 'Completed Items' ).

      lo_column ?= io_columns->get_column( 'DELETED_COUNT' ).
      lo_column->set_medium_text( 'Deleted' ).
      lo_column->set_long_text( 'Deleted Items' ).

      lo_column ?= io_columns->get_column( 'ON_TIME_PCT' ).
      lo_column->set_medium_text( 'On-Time %' ).
      lo_column->set_long_text( 'On-Time Delivery Percentage' ).

    CATCH cx_salv_not_found.
  ENDTRY.

ENDFORM.
