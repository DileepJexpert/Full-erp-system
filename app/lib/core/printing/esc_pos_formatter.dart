import 'dart:convert';
import 'dart:typed_data';

import 'package:intl/intl.dart';

import 'receipt_template.dart';

/// Formats [ReceiptData] into raw ESC/POS byte commands suitable for 58 mm or
/// 80 mm thermal printers connected over Bluetooth.
///
/// Uses standard ESC/POS command set -- no external library needed at runtime.
class EscPosFormatter {
  EscPosFormatter._();

  // ---------------------------------------------------------------------------
  // ESC/POS command constants
  // ---------------------------------------------------------------------------

  /// Initialize printer.
  static const _escInit = [0x1B, 0x40]; // ESC @

  /// Select justification: 0=left, 1=center, 2=right.
  static List<int> _align(int n) => [0x1B, 0x61, n]; // ESC a n

  /// Select character size. n encodes width multiplier in high nibble, height
  /// in low nibble. 0x00 = normal, 0x11 = double W+H.
  static List<int> _textSize(int n) => [0x1D, 0x21, n]; // GS ! n

  /// Line feed.
  static const _lf = [0x0A];

  /// Print and feed n lines.
  static List<int> _feedLines(int n) => [0x1B, 0x64, n]; // ESC d n

  /// Select bold mode: 0=off, 1=on.
  static List<int> _bold(bool on) => [0x1B, 0x45, on ? 1 : 0]; // ESC E n

  /// Full cut (with small feed).
  static const _cut = [0x1D, 0x56, 0x41, 0x03]; // GS V A 3

  // Receipt column width (number of characters on a 58 mm printer).
  static const int _lineWidth = 32;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Convert a [ReceiptData] into a complete byte sequence ready to send to
  /// the printer.
  static List<int> formatReceipt(ReceiptData receipt) {
    final bytes = <int>[];
    final currFmt = NumberFormat('#,##0.00', 'en_IN');

    bytes.addAll(_escInit);

    // ---- Header -----------------------------------------------------------
    bytes.addAll(_align(1)); // center
    bytes.addAll(_textSize(0x11)); // double size
    bytes.addAll(_bold(true));
    bytes.addAll(_line('═' * (_lineWidth ~/ 2)));
    bytes.addAll(_text(receipt.businessName));
    bytes.addAll(_line('═' * (_lineWidth ~/ 2)));
    bytes.addAll(_textSize(0x00)); // normal
    bytes.addAll(_bold(false));

    if (receipt.locationName.isNotEmpty) {
      bytes.addAll(_text('Location: ${receipt.locationName}'));
    }

    final dateFmt = DateFormat('dd/MM/yyyy');
    final timeFmt = DateFormat('HH:mm');
    bytes.addAll(
        _text('Date: ${dateFmt.format(receipt.dateTime)}  '
            'Time: ${timeFmt.format(receipt.dateTime)}'));
    bytes.addAll(_text('Bill #: ${receipt.billNumber}'));
    if (receipt.customerPhone != null && receipt.customerPhone!.isNotEmpty) {
      bytes.addAll(_text('Customer: ${receipt.customerPhone}'));
    }

    // ---- Column header ----------------------------------------------------
    bytes.addAll(_align(0)); // left
    bytes.addAll(_separator());
    bytes.addAll(_text(_row('Item', 'Qty', 'Amount')));
    bytes.addAll(_separator());

    // ---- Items ------------------------------------------------------------
    for (final item in receipt.items) {
      final amt = '₹${currFmt.format(item.lineTotal)}';
      final qty = 'x${item.quantity}';
      bytes.addAll(_text(_row(_truncate(item.name, 16), qty, amt)));
    }

    bytes.addAll(_separator());

    // ---- Totals -----------------------------------------------------------
    bytes.addAll(_textRow('Subtotal:', '₹${currFmt.format(receipt.subtotal)}'));

    if (receipt.cgstTotal > 0) {
      final halfRate = receipt.effectiveGstRate / 2;
      final cgstLabel = halfRate > 0
          ? 'CGST (${_fmtRate(halfRate)}%):'
          : 'CGST:';
      final sgstLabel = halfRate > 0
          ? 'SGST (${_fmtRate(halfRate)}%):'
          : 'SGST:';
      bytes.addAll(
          _textRow(cgstLabel, '₹${currFmt.format(receipt.cgstTotal)}'));
      bytes.addAll(
          _textRow(sgstLabel, '₹${currFmt.format(receipt.sgstTotal)}'));
    }

    bytes.addAll(_separator());
    bytes.addAll(_bold(true));
    bytes.addAll(_textSize(0x01)); // double height
    bytes.addAll(
        _textRow('TOTAL:', '₹${currFmt.format(receipt.grandTotal)}'));
    bytes.addAll(_textSize(0x00));
    bytes.addAll(_bold(false));

    // ---- Payment ----------------------------------------------------------
    bytes.addAll(_text('Payment: ${receipt.paymentMode}'));
    if (receipt.paymentMode == 'MIXED') {
      bytes.addAll(
          _text('  Cash: ₹${currFmt.format(receipt.cashAmount)}'));
      bytes.addAll(
          _text('  UPI:  ₹${currFmt.format(receipt.upiAmount)}'));
    }
    if (receipt.upiRef != null && receipt.upiRef!.isNotEmpty) {
      bytes.addAll(_text('UPI Ref: ${receipt.upiRef}'));
    }

    // ---- Footer -----------------------------------------------------------
    bytes.addAll(_align(1)); // center
    bytes.addAll(_line('═' * _lineWidth));
    bytes.addAll(
        _text(receipt.footerMessage ?? 'Thank you! Visit again.'));
    bytes.addAll(_feedLines(4));
    bytes.addAll(_cut);

    return bytes;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static List<int> _text(String s) {
    return [...utf8.encode(s), ..._lf];
  }

  static List<int> _line(String s) => _text(s);

  static List<int> _separator() =>
      _text('─' * _lineWidth);

  /// Three-column row for Item / Qty / Amount.
  static String _row(String col1, String col2, String col3) {
    const c1 = 16;
    const c2 = 6;
    // c3 fills rest
    final c3 = _lineWidth - c1 - c2;
    return col1.padRight(c1) + col2.padRight(c2) + col3.padLeft(c3);
  }

  /// Two-column row for Label / Value (right-aligned value).
  static List<int> _textRow(String label, String value) {
    final padded =
        label.padRight(_lineWidth - value.length) + value;
    return _text(padded);
  }

  static String _truncate(String s, int max) {
    if (s.length <= max) return s;
    return '${s.substring(0, max - 1)}…';
  }

  static String _fmtRate(double rate) {
    return rate == rate.roundToDouble()
        ? rate.toInt().toString()
        : rate.toStringAsFixed(1);
  }
}
