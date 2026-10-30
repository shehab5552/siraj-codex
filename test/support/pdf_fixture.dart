import 'dart:convert';
import 'dart:typed_data';

/// Synthetic layout/text document. Not a textbook, curriculum, or AI resource.
Uint8List syntheticPdf() {
  final data = BytesBuilder()..add(ascii.encode('%PDF-1.4\n'));
  final offsets = <int>[0];
  void object(int id, String body) {
    offsets.add(data.length);
    data.add(ascii.encode('$id 0 obj\n$body\nendobj\n'));
  }

  object(1, '<< /Type /Catalog /Pages 2 0 R >>');
  object(2, '<< /Type /Pages /Kids [3 0 R 5 0 R] /Count 2 >>');
  String page(int contents) =>
      '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 300 400] /Resources << /Font << /F1 7 0 R >> >> /Contents $contents 0 R >>';
  String stream(int number) {
    final content =
        '0.1 0.3 0.6 rg 20 200 260 ${number * 30} re f\nBT /F1 14 Tf 20 350 Td (SIRAJ SYNTHETIC PDF TEST - PAGE $number) Tj ET\n';
    return '<< /Length ${ascii.encode(content).length} >>\nstream\n${content}endstream';
  }

  object(3, page(4));
  object(4, stream(1));
  object(5, page(6));
  object(6, stream(2));
  object(7, '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>');
  final xref = data.length;
  data.add(ascii.encode('xref\n0 8\n0000000000 65535 f \n'));
  for (final offset in offsets.skip(1)) {
    data.add(ascii.encode('${offset.toString().padLeft(10, '0')} 00000 n \n'));
  }
  data.add(
    ascii.encode(
      'trailer\n<< /Size 8 /Root 1 0 R >>\nstartxref\n$xref\n%%EOF\n',
    ),
  );
  return data.toBytes();
}
