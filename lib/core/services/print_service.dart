import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/invoice.dart';
import '../services/storage_service.dart';
import '../utils/currency_formatter.dart';

class PrintService {
  /// Generates thermal-style PDF receipt
  static Future<Uint8List> generateReceiptPdf(Invoice invoice) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.cairoRegular();
    final fontBold = await PdfGoogleFonts.cairoBold();

    final storeName = StorageService.getStoreName();
    final storePhone = StorageService.getStorePhone();
    final storeAddress = StorageService.getStoreAddress();

    pdf.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(58 * PdfPageFormat.mm, double.infinity, marginAll: 2 * PdfPageFormat.mm),
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        textDirection: pw.TextDirection.rtl,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // Store Header
              pw.Text(storeName, style: pw.TextStyle(font: fontBold, fontSize: 13), textAlign: pw.TextAlign.center),
              if (storeAddress.isNotEmpty)
                pw.Text(storeAddress, style: pw.TextStyle(font: font, fontSize: 8), textAlign: pw.TextAlign.center),
              if (storePhone.isNotEmpty)
                pw.Text('هاتف: $storePhone', style: pw.TextStyle(font: font, fontSize: 8), textAlign: pw.TextAlign.center),
              pw.Divider(thickness: 0.5),

              // Invoice metadata
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('رقم: ${invoice.invoiceNumber}', style: pw.TextStyle(font: font, fontSize: 8)),
                  pw.Text(
                    DateFormat('yyyy/MM/dd HH:mm').format(DateTime.tryParse(invoice.createdAt) ?? DateTime.now()),
                    style: pw.TextStyle(font: font, fontSize: 7),
                  ),
                ],
              ),
              if (invoice.customerName != null) ...[
                pw.SizedBox(height: 2),
                pw.Row(
                  children: [
                    pw.Text('الزبون: ${invoice.customerName}', style: pw.TextStyle(font: fontBold, fontSize: 8)),
                  ],
                ),
              ],
              pw.Divider(thickness: 0.5),

              // Table header
              pw.Row(
                children: [
                  pw.Expanded(flex: 4, child: pw.Text('السلعة', style: pw.TextStyle(font: fontBold, fontSize: 8))),
                  pw.Expanded(flex: 2, child: pw.Text('الكمية', style: pw.TextStyle(font: fontBold, fontSize: 8), textAlign: pw.TextAlign.center)),
                  pw.Expanded(flex: 2, child: pw.Text('السعر', style: pw.TextStyle(font: fontBold, fontSize: 8), textAlign: pw.TextAlign.center)),
                  pw.Expanded(flex: 2, child: pw.Text('المجموع', style: pw.TextStyle(font: fontBold, fontSize: 8), textAlign: pw.TextAlign.left)),
                ],
              ),
              pw.Divider(thickness: 0.3),

              // Items
              ...invoice.items.map((item) {
                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
                  child: pw.Row(
                    children: [
                      pw.Expanded(flex: 4, child: pw.Text(item.product.name, style: pw.TextStyle(font: font, fontSize: 7.5))),
                      pw.Expanded(flex: 2, child: pw.Text('${item.quantity}', style: pw.TextStyle(font: font, fontSize: 7.5), textAlign: pw.TextAlign.center)),
                      pw.Expanded(flex: 2, child: pw.Text('${item.unitPrice.round()}', style: pw.TextStyle(font: font, fontSize: 7.5), textAlign: pw.TextAlign.center)),
                      pw.Expanded(flex: 2, child: pw.Text('${item.subtotal.round()}', style: pw.TextStyle(font: fontBold, fontSize: 7.5), textAlign: pw.TextAlign.left)),
                    ],
                  ),
                );
              }),

              pw.Divider(thickness: 0.5),

              // Totals
              if (invoice.discount > 0)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('الخصم:', style: pw.TextStyle(font: font, fontSize: 8)),
                    pw.Text('-${CurrencyFormatter.format(invoice.discount)}', style: pw.TextStyle(font: font, fontSize: 8)),
                  ],
                ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('الإجمالي الصافي:', style: pw.TextStyle(font: fontBold, fontSize: 10)),
                  pw.Text(CurrencyFormatter.format(invoice.totalAmount), style: pw.TextStyle(font: fontBold, fontSize: 10)),
                ],
              ),

              pw.SizedBox(height: 2),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('طريقة الدفع:', style: pw.TextStyle(font: font, fontSize: 8)),
                  pw.Text(
                    invoice.paymentType == PaymentType.cash
                        ? 'نقدي'
                        : invoice.paymentType == PaymentType.credit
                            ? 'آجل (كريدي)'
                            : 'دفع جزئي',
                    style: pw.TextStyle(font: font, fontSize: 8),
                  ),
                ],
              ),

              if (invoice.paymentType == PaymentType.cash && invoice.changeGiven > 0) ...[
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('المدفوع:', style: pw.TextStyle(font: font, fontSize: 8)),
                    pw.Text(CurrencyFormatter.format(invoice.paidAmount), style: pw.TextStyle(font: font, fontSize: 8)),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('الفكة المتبقية:', style: pw.TextStyle(font: fontBold, fontSize: 8)),
                    pw.Text(CurrencyFormatter.format(invoice.changeGiven), style: pw.TextStyle(font: fontBold, fontSize: 8)),
                  ],
                ),
              ],

              if (invoice.remainingDebt > 0) ...[
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('المتبقي كدين:', style: pw.TextStyle(font: fontBold, fontSize: 8)),
                    pw.Text(CurrencyFormatter.format(invoice.remainingDebt), style: pw.TextStyle(font: fontBold, fontSize: 8)),
                  ],
                ),
              ],

              pw.SizedBox(height: 6),
              pw.Text('شكراً لزيارتكم! مرحباً بكم دائماً', style: pw.TextStyle(font: font, fontSize: 7), textAlign: pw.TextAlign.center),
              pw.SizedBox(height: 10),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Print directly via bluetooth/system printer
  static Future<void> printReceipt(Invoice invoice) async {
    try {
      final pdfData = await generateReceiptPdf(invoice);
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfData,
        name: 'فاتورة_${invoice.invoiceNumber}.pdf',
      );
    } catch (_) {}
  }

  /// Format invoice text for sharing via WhatsApp
  static String formatInvoiceWhatsAppText(Invoice invoice) {
    final storeName = StorageService.getStoreName();
    final storePhone = StorageService.getStorePhone();

    final buffer = StringBuffer();
    buffer.writeln('🧾 *فاتورة مبيعات - $storeName*');
    if (storePhone.isNotEmpty) buffer.writeln('📞 هاتف: $storePhone');
    buffer.writeln('🔢 رقم الفاتورة: ${invoice.invoiceNumber}');
    buffer.writeln('📅 التاريخ: ${DateFormat('yyyy/MM/dd HH:mm').format(DateTime.tryParse(invoice.createdAt) ?? DateTime.now())}');
    if (invoice.customerName != null) buffer.writeln('👤 الزبون: ${invoice.customerName}');
    buffer.writeln('------------------------------');

    for (var item in invoice.items) {
      buffer.writeln('▪️ ${item.product.name}');
      buffer.writeln('   ${item.quantity} × ${item.unitPrice.round()} دج = *${item.subtotal.round()} دج*');
    }

    buffer.writeln('------------------------------');
    if (invoice.discount > 0) {
      buffer.writeln('🏷️ الخصم: -${invoice.discount.round()} دج');
    }
    buffer.writeln('💰 *الإجمالي الصافي: ${CurrencyFormatter.format(invoice.totalAmount)}*');

    if (invoice.paymentType == PaymentType.cash) {
      buffer.writeln('💵 طريقة الدفع: نقدي');
      if (invoice.changeGiven > 0) {
        buffer.writeln('↩️ الفكة المرجعة: ${CurrencyFormatter.format(invoice.changeGiven)}');
      }
    } else if (invoice.paymentType == PaymentType.credit) {
      buffer.writeln('⏳ طريقة الدفع: آجل (كريدي بالكامل)');
      buffer.writeln('⚠️ الدين المتبقي: ${CurrencyFormatter.format(invoice.remainingDebt)}');
    } else {
      buffer.writeln('💳 طريقة الدفع: دفع جزئي');
      buffer.writeln('💵 المدفوع: ${CurrencyFormatter.format(invoice.paidAmount)}');
      buffer.writeln('⚠️ الدين المتبقي: ${CurrencyFormatter.format(invoice.remainingDebt)}');
    }

    buffer.writeln('\n🙏 شكراً لتعاملكم معنا!');
    return buffer.toString();
  }

  /// Share WhatsApp receipt
  static Future<void> shareInvoiceViaWhatsApp(Invoice invoice) async {
    final text = formatInvoiceWhatsAppText(invoice);
    await Share.share(text, subject: 'فاتورة ${invoice.invoiceNumber}');
  }

  /// Share invoice PDF directly
  static Future<void> shareInvoicePdf(Invoice invoice) async {
    try {
      final pdfData = await generateReceiptPdf(invoice);
      await Printing.sharePdf(bytes: pdfData, filename: 'invoice_${invoice.invoiceNumber}.pdf');
    } catch (_) {
      await shareInvoiceViaWhatsApp(invoice);
    }
  }

  /// Share shortages list with supplier via WhatsApp
  static Future<void> shareShortagesList({
    required List<Map<String, dynamic>> shortages,
    String? supplierName,
  }) async {
    final storeName = StorageService.getStoreName();
    final buffer = StringBuffer();
    buffer.writeln('📦 *قائمة النواقص والسلع المطلوبة*');
    buffer.writeln('🏪 المحل: $storeName');
    if (supplierName != null) buffer.writeln('🚚 المورد: $supplierName');
    buffer.writeln('📅 التاريخ: ${DateFormat('yyyy/MM/dd').format(DateTime.now())}');
    buffer.writeln('------------------------------');

    for (int i = 0; i < shortages.length; i++) {
      final item = shortages[i];
      buffer.writeln('${i + 1}. ${item['name']} (الكمية المطلوبة: ${item['requested_qty'] ?? 10})');
    }

    buffer.writeln('------------------------------');
    buffer.writeln('يرجى تجهيز الطلبية في أقرب وقت. وشكراً!');

    await Share.share(buffer.toString(), subject: 'طلبية نواقص - $storeName');
  }
}
