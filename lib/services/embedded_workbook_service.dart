import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';

/// Builds real `.xlsx` workbooks (Track 09, FEAT 3) with the minimal part
/// set PowerPoint expects: `sheet1` + `sharedStrings` (shared strings per
/// spec), so the "Edit Data in Excel" flow opens the numbers directly.
///
/// The sheet layout is the Excel-chart convention:
///   A1 empty · B1.. series names · A2.. categories · B2.. values.
class EmbeddedWorkbookService {
  EmbeddedWorkbookService._();

  /// Serialize the grid (row-major strings/numbers) into an xlsx byte array.
  static Uint8List buildXlsx(List<List<Object?>> grid) {
    final rows = grid.length;
    final cols = grid.fold<int>(0, (m, row) => row.length > m ? row.length : m);
    final lastCol = _alpha(cols);
    final lastRow = rows;

    // Shared strings: unique text cells, referenced by index (t="s").
    final shared = <String>[];
    final cellRefs = <String, int>{};
    for (final row in grid) {
      for (final cell in row) {
        if (cell is String && cell.isNotEmpty && !shared.contains(cell)) {
          cellRefs[cell] = shared.length;
          shared.add(cell);
        }
      }
    }

    final archive = Archive();
    void addText(String name, String content) {
      final bytes = utf8.encode(content);
      archive.addFile(
          ArchiveFile(name, bytes.length, Uint8List.fromList(bytes)));
    }

    addText('[Content_Types].xml', '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
<Default Extension="xml" ContentType="application/xml"/>
<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
<Override PartName="/xl/theme/theme1.xml" ContentType="application/vnd.openxmlformats-officedocument.theme+xml"/>
<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
<Override PartName="/xl/sharedStrings.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml"/>
<Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
<Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>
</Types>''');
    addText('_rels/.rels', '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
<Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>
</Relationships>''');
    addText('xl/workbook.xml', '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
<workbookPr defaultThemeVersion="202300"/>
<bookViews><workbookView xWindow="-108" yWindow="-108" windowWidth="23256" windowHeight="12456"/></bookViews>
<sheets><sheet name="Sheet1" sheetId="1" r:id="rId1"/></sheets>
<calcPr calcId="191029"/>
</workbook>''');
    addText('xl/_rels/workbook.xml.rels', '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme" Target="theme/theme1.xml"/>
<Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
<Relationship Id="rId4" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/sharedStrings" Target="sharedStrings.xml"/>
</Relationships>''');

    final sheet = StringBuffer()
      ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n')
      ..write(
          '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">')
      ..write('<dimension ref="A1:$lastCol$lastRow"/>')
      ..write('<sheetViews><sheetView tabSelected="1" workbookViewId="0"/></sheetViews>')
      ..write('<sheetFormatPr defaultRowHeight="14.4"/><sheetData>');
    for (var r = 0; r < rows; r++) {
      final row = grid[r];
      sheet.write('<row r="${r + 1}">');
      for (var c = 0; c < cols; c++) {
        final cell = c < row.length ? row[c] : null;
        final ref = '${_alpha(c + 1)}${r + 1}';
        if (cell is num) {
          sheet.write('<c r="$ref"><v>$cell</v></c>');
        } else if (cell is String && cell.isNotEmpty) {
          final s = cellRefs[cell]!;
          sheet.write('<c r="$ref" t="s"><v>$s</v></c>');
        } else {
          sheet.write('<c r="$ref"/>');
        }
      }
      sheet.write('</row>');
    }
    sheet.write('</sheetData>');
    sheet.write(
        '<pageMargins left="0.7" right="0.7" top="0.75" bottom="0.75" header="0.3" footer="0.3"/>');
    sheet.write('</worksheet>');
    addText('xl/worksheets/sheet1.xml', sheet.toString());

    final strings = StringBuffer()
      ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n')
      ..write(
          '<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" count="${_countStrings(grid)}" uniqueCount="${shared.length}">');
    for (final s in shared) {
      strings
        ..write('<si><t>')
        ..write(_xml(s))
        ..write('</t></si>');
    }
    strings.write('</sst>');
    addText('xl/sharedStrings.xml', strings.toString());

    addText('xl/styles.xml', '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
<fonts count="1"><font><sz val="11"/><name val="Calibri"/></font></fonts>
<fills count="2"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill></fills>
<borders count="1"><border/></borders>
<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>
<cellXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/></cellXfs>
</styleSheet>''');

    addText('xl/theme/theme1.xml', _themeXml);
    addText('docProps/core.xml', '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
<dc:creator>Ghita PPT Converter</dc:creator>
<cp:lastModifiedBy>Ghita PPT Converter</cp:lastModifiedBy>
</cp:coreProperties>''');
    addText('docProps/app.xml', '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">
<Application>Ghita PPT Converter</Application>
</Properties>''');

    return Uint8List.fromList(ZipEncoder().encode(archive)!);
  }

  /// Minimal but schema-complete workbook theme (same shape as the Office
  /// theme part PowerPoint writes).
  static const String _themeXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<a:theme xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" name="Office Theme">
<a:themeElements>
<a:clrScheme name="Office">
<a:dk1><a:sysClr val="windowText" lastClr="000000"/></a:dk1>
<a:lt1><a:sysClr val="window" lastClr="FFFFFF"/></a:lt1>
<a:dk2><a:srgbClr val="44546A"/></a:dk2>
<a:lt2><a:srgbClr val="E7E6E6"/></a:lt2>
<a:accent1><a:srgbClr val="4472C4"/></a:accent1>
<a:accent2><a:srgbClr val="ED7D31"/></a:accent2>
<a:accent3><a:srgbClr val="A5A5A5"/></a:accent3>
<a:accent4><a:srgbClr val="FFC000"/></a:accent4>
<a:accent5><a:srgbClr val="5B9BD5"/></a:accent5>
<a:accent6><a:srgbClr val="70AD47"/></a:accent6>
<a:hlink><a:srgbClr val="0563C1"/></a:hlink>
<a:folHlink><a:srgbClr val="954F72"/></a:folHlink>
</a:clrScheme>
<a:fontScheme name="Office">
<a:majorFont><a:latin typeface="Calibri Light"/><a:ea typeface=""/><a:cs typeface=""/></a:majorFont>
<a:minorFont><a:latin typeface="Calibri"/><a:ea typeface=""/><a:cs typeface=""/></a:minorFont>
</a:fontScheme>
<a:fmtScheme name="Office">
<a:fillStyleLst><a:solidFill><a:schemeClr val="phClr"/></a:solidFill><a:solidFill><a:schemeClr val="phClr"/></a:solidFill><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:fillStyleLst>
<a:lnStyleLst><a:ln w="9525" cap="flat" cmpd="sng" algn="ctr"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill><a:prstDash val="solid"/></a:ln><a:ln w="9525" cap="flat" cmpd="sng" algn="ctr"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill><a:prstDash val="solid"/></a:ln><a:ln w="9525" cap="flat" cmpd="sng" algn="ctr"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill><a:prstDash val="solid"/></a:ln></a:lnStyleLst>
<a:effectStyleLst><a:effectStyle><a:effectLst/></a:effectStyle><a:effectStyle><a:effectLst/></a:effectStyle><a:effectStyle><a:effectLst/></a:effectStyle></a:effectStyleLst>
<a:bgFillStyleLst><a:solidFill><a:schemeClr val="phClr"/></a:solidFill><a:solidFill><a:schemeClr val="phClr"/></a:solidFill><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:bgFillStyleLst>
</a:fmtScheme>
</a:themeElements>
</a:theme>''';

  static int _countStrings(List<List<Object?>> grid) => grid.fold(
      0,
      (n, row) => n +
          row.whereType<String>().where((s) => s.isNotEmpty).length);

  static String _alpha(int number) {
    var n = number;
    final sb = StringBuffer();
    while (n > 0) {
      n--;
      sb.writeCharCode(65 + n % 26);
      n ~/= 26;
    }
    return sb.toString();
  }

  static String _xml(String text) => text
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');

  // ---- CSV (P6) ---------------------------------------------------------

  /// Parse a basic CSV payload into rows of strings (handles quoted cells
  /// with commas and escaped double quotes).
  static List<List<String>> parseCsv(String csv) {
    final rows = <List<String>>[];
    var row = <String>[];
    final buffer = StringBuffer();
    var inQuotes = false;
    var i = 0;
    while (i < csv.length) {
      final ch = csv[i];
      if (inQuotes) {
        if (ch == '"') {
          if (i + 1 < csv.length && csv[i + 1] == '"') {
            buffer.write('"');
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          buffer.write(ch);
        }
      } else if (ch == '"') {
        inQuotes = true;
      } else if (ch == ',') {
        row.add(buffer.toString());
        buffer.clear();
      } else if (ch == '\n' || ch == '\r') {
        if (ch == '\r' && i + 1 < csv.length && csv[i + 1] == '\n') {
          i++;
        }
        row.add(buffer.toString());
        buffer.clear();
        rows.add(row);
        row = <String>[];
      } else {
        buffer.write(ch);
      }
      i++;
    }
    if (buffer.isNotEmpty || row.isNotEmpty) {
      row.add(buffer.toString());
      rows.add(row);
    }
    return rows;
  }
}