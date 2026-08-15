
import '../models/smartart.dart';

/// Generated OOXML SmartArt package (Track 10, P3): `data{n}.xml` +
/// `layout{n}.xml` + `quickStyle{n}.xml` + `colors{n}.xml`, wired through
/// `dgm:relIds` in the slide, per DrawingML Diagrams.
///
/// The layout definition is a minimal flat generic layout (documented) — the
/// data model, presId mapping and package structure follow the schema, and
/// PowerPoint substitutes its own layout when the generic one is replaced.
///
/// Verified against real PowerPoint (Track 10, P8): the deck opens and the
/// diagram renders only when (a) the slide binds the parts via
/// `<dgm:relIds r:dm/r:lo/r:qs/r:cs>` (the legacy `dgm:diagram` attribute form
/// makes PowerPoint reject the whole file) and (b) every `<dgm:t>` is a full
/// `a:bodyPr/a:lstStyle/a:p` text body — a bare text string crashes the
/// diagram engine on load.
class PptSmartArtPackage {
  PptSmartArtPackage({
    required this.dataXml,
    required this.layoutXml,
    required this.quickStyleXml,
    required this.colorsXml,
  });

  final String dataXml;
  final String layoutXml;
  final String quickStyleXml;
  final String colorsXml;
}

class PptSmartArtWriter {
  PptSmartArtWriter._();

  static PptSmartArtPackage build(SmartArtGraph graph) {
    return PptSmartArtPackage(
      dataXml: _dataXml(graph),
      layoutXml: _layoutXml,
      quickStyleXml: _quickStyleXml,
      colorsXml: _colorsXml(graph),
    );
  }

  // ---- data{n}.xml ------------------------------------------------------

  static String _dataXml(SmartArtGraph graph) {
    final nodes = graph.orderedNodes;
    final b = StringBuffer()
      ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n')
      ..write(
          '<dgm:dataModel xmlns:dgm="http://schemas.openxmlformats.org/drawingml/2006/diagram" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">')
      ..write('<dgm:ptLst>');
    // Document node (the canvas).
    b.write('<dgm:pt modelId="0" type="doc">'
        '<dgm:prSet/>'
        '<dgm:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/></a:xfrm>'
        '<a:prstGeom prst="rect"><a:avLst/></a:prstGeom></dgm:spPr>'
        '</dgm:pt>');
    for (var i = 0; i < nodes.length; i++) {
      final n = nodes[i];
      final isTop = n.parentId == null;
      b
        ..write('<dgm:pt modelId="${n.id + 1}" type="${isTop ? 'node' : 'node'}">')
        ..write('<dgm:prSet/>')
        ..write('<dgm:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/></a:xfrm>'
            '<a:prstGeom prst="rect"><a:avLst/></a:prstGeom></dgm:spPr>')
        ..write('<dgm:t><a:bodyPr/><a:lstStyle/><a:p><a:r><a:t>${_xml(n.text)}</a:t></a:r></a:p></dgm:t>')
        ..write('</dgm:pt>');
    }
    b.write('</dgm:ptLst><dgm:cxnLst>');
    var cxn = 1;
    for (var i = 0; i < nodes.length; i++) {
      final n = nodes[i];
      final src = n.parentId == null ? 0 : n.parentId! + 1;
      b
        ..write('<dgm:cxn modelId="$cxn" srcId="$src" destId="${n.id + 1}" '
            'srcOrd="0" destOrd="0" parTransId="0" sibTransId="0">')
        ..write('<dgm:presId val="node1"/></dgm:cxn>');
      cxn++;
    }
    b.write('</dgm:cxnLst></dgm:dataModel>');
    return b.toString();
  }

  // ---- layout{n}.xml (minimal generic flat layout) ----------------------

  static const String _layoutXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<dgm:layoutDef xmlns:dgm="http://schemas.openxmlformats.org/drawingml/2006/diagram" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" uniqueId="urn:ghita:smartart:flat" minVer="http://schemas.openxmlformats.org/drawingml/2006/diagram">
<dgm:title val="Ghita SmartArt"/>
<dgm:desc val="Flat nodes"/>
<dgm:catLst><dgm:cat type="process" pri="1000"/></dgm:catLst>
<dgm:sampData><dgm:ptLst>
<dgm:pt modelId="0" type="doc"><dgm:prSet/><dgm:spPr><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></dgm:spPr></dgm:pt>
<dgm:pt modelId="1" type="node"><dgm:prSet/><dgm:spPr><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></dgm:spPr><dgm:t>Text</dgm:t></dgm:pt>
</dgm:ptLst></dgm:sampData>
<dgm:styleData>
<dgm:styleLbl name="node0" scene3d="0" f3d="0" f3dPr="0" f3dAvail="0"><dgm:style><a:lnRef idx="2"><a:schemeClr val="accent1"/></a:lnRef><a:fillRef idx="1"><a:schemeClr val="accent1"/></a:fillRef><a:effectRef idx="0"><a:schemeClr val="accent1"/></a:effectRef><a:fontRef idx="minor"><a:schemeClr val="tx1"/></a:fontRef></dgm:style></dgm:styleLbl>
<dgm:styleLbl name="node1" scene3d="0" f3d="0" f3dPr="0" f3dAvail="0"><dgm:style><a:lnRef idx="2"><a:schemeClr val="accent1"/></a:lnRef><a:fillRef idx="1"><a:schemeClr val="accent1"/></a:fillRef><a:effectRef idx="0"><a:schemeClr val="accent1"/></a:effectRef><a:fontRef idx="minor"><a:schemeClr val="tx1"/></a:fontRef></dgm:style></dgm:styleLbl>
</dgm:styleData>
<dgm:clrData>
<dgm:clrLbl name="tx1" clrType="tx1"><a:schemeClr val="tx1"/></dgm:clrLbl>
<dgm:clrLbl name="accent1" clrType="accent1"><a:schemeClr val="accent1"/></dgm:clrLbl>
</dgm:clrData>
<dgm:layoutNode name="node0" styleLbl="node0" chOrder="0" moveWith="1">
<dgm:alg type="lin"><dgm:param type="w" val="100%"/></dgm:alg>
<dgm:shape type="roundRect"/>
<dgm:tx><dgm:txPr><a:bodyPr/><a:lstStyle/><a:p><a:pPr algn="ctr"/><a:defRPr sz="1200"/></a:p></dgm:txPr><dgm:txXfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/></dgm:txXfrm></dgm:tx>
<dgm:childLay>
<dgm:layoutNode name="node1" styleLbl="node1" chOrder="1">
<dgm:alg type="lin"><dgm:param type="w" val="100%"/></dgm:alg>
<dgm:shape type="roundRect"/>
<dgm:tx><dgm:txPr><a:bodyPr/><a:lstStyle/><a:p><a:pPr algn="ctr"/><a:defRPr sz="1200"/></a:p></dgm:txPr><dgm:txXfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/></dgm:txXfrm></dgm:tx>
</dgm:layoutNode>
</dgm:childLay>
</dgm:layoutNode>
</dgm:layoutDef>''';

  static String get _quickStyleXml => '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<dgm:quickStyle xmlns:dgm="http://schemas.openxmlformats.org/drawingml/2006/diagram" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
<dgm:styleLbl name="node0" scene3d="0" f3d="0" f3dPr="0" f3dAvail="0"><dgm:style><a:lnRef idx="2"><a:schemeClr val="accent1"/></a:lnRef><a:fillRef idx="1"><a:schemeClr val="accent1"/></a:fillRef><a:effectRef idx="0"><a:schemeClr val="accent1"/></a:effectRef><a:fontRef idx="minor"><a:schemeClr val="tx1"/></a:fontRef></dgm:style></dgm:styleLbl>
<dgm:styleLbl name="node1" scene3d="0" f3d="0" f3dPr="0" f3dAvail="0"><dgm:style><a:lnRef idx="2"><a:schemeClr val="accent2"/></a:lnRef><a:fillRef idx="1"><a:schemeClr val="accent2"/></a:fillRef><a:effectRef idx="0"><a:schemeClr val="accent2"/></a:effectRef><a:fontRef idx="minor"><a:schemeClr val="tx1"/></a:fontRef></dgm:style></dgm:styleLbl>
</dgm:quickStyle>''';

  static String _colorsXml(SmartArtGraph graph) {
    final accent = graph.colorTheme.colors;
    final b = StringBuffer()
      ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n')
      ..write(
          '<dgm:colorsDef xmlns:dgm="http://schemas.openxmlformats.org/drawingml/2006/diagram" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" uniqueId="urn:ghita:smartart:colors" minVer="http://schemas.openxmlformats.org/drawingml/2006/diagram">')
      ..write('<dgm:title val="${graph.colorTheme.label}"/>')
      ..write('<dgm:desc val="${graph.colorTheme.label}"/>')
      ..write('<dgm:catLst><dgm:cat type="accent" pri="1000"/></dgm:catLst>')
      ..write('<dgm:styleLbl name="node0"><dgm:style><a:fillRef idx="1"><a:srgbClr val="${accent[0]}"/></a:fillRef></dgm:style></dgm:styleLbl>')
      ..write('<dgm:styleLbl name="node1"><dgm:style><a:fillRef idx="1"><a:srgbClr val="${accent[1 % accent.length]}"/></a:fillRef></dgm:style></dgm:styleLbl>')
      ..write('</dgm:colorsDef>');
    return b.toString();
  }

  static String _xml(String text) => text
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}