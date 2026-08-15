import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../services/equation_service.dart';

/// "Chèn công thức" dialog (Track 18, P3–P4): choose a formula template
/// (fraction, sqrt, sum, integral, matrix, plain), returns an [EquationData].
class EquationDialog extends StatefulWidget {
  const EquationDialog({super.key});

  @override
  State<EquationDialog> createState() => _EquationDialogState();
}

class _EquationDialogState extends State<EquationDialog> {
  static const Map<String, String> _templates = {
    'Fraction': '<math><mfrac><mn>1</mn><mn>2</mn></mfrac></math>',
    'Square root': '<math><msqrt><mi>x</mi><mo>+</mo><mn>1</mn></msqrt></math>',
    'Quadratic': '<math><mi>x</mi><mo>=</mo><mfrac><mrow><mo>−</mo><mi>b</mi><mo>±</mo><msqrt><msup><mi>b</mi><mn>2</mn></msup><mo>−</mo><mn>4</mn><mi>a</mi><mi>c</mi></msqrt></mrow><mrow><mn>2</mn><mi>a</mi></mrow></mfrac></math>',
    'Sum': '<math><munderover><mo>∑</mo><mrow><mi>i</mi><mo>=</mo><mn>1</mn></mrow><mi>n</mi></munderover><msup><mi>x</mi><mi>i</mi></msup></math>',
    'Integral': '<math><mrow><mo>∫</mo><msup><mi>x</mi><mn>2</mn></msup><mi>dx</mi></mrow></math>',
    'Matrix 2×2': '<math><mtable><mtr><mtd><mi>a</mi></mtd><mtd><mi>b</mi></mtd></mtr><mtr><mtd><mi>c</mi></mtd><mtd><mi>d</mi></mtd></mtr></mtable></math>',
    'Plain': '<math><mi>E</mi><mo>=</mo><mi>m</mi><msup><mi>c</mi><mn>2</mn></msup></math>',
  };

  String _template = _templates.keys.first;
  String _customMathml = '';

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Row(children: [
        const Icon(Icons.functions_outlined),
        const SizedBox(width: 10),
        Text(l.equation),
      ]),
      content: SizedBox(
        width: 460,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _template,
              decoration: InputDecoration(
                labelText: l.equationTemplate,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                for (final key in _templates.keys)
                  DropdownMenuItem(value: key, child: Text(key)),
              ],
              onChanged: (v) => setState(() => _template = v ?? _templates.keys.first),
            ),
            const SizedBox(height: 10),
            // Preview of the selected template (plain text fallback)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                EquationData(latex: _templates[_template]!).htmlMarkup
                    .replaceAll(RegExp(r'<[^>]+>'), '')
                    .replaceAll('data-equation-html', ''),
                style: const TextStyle(
                  fontFamily: 'Cambria Math',
                  fontStyle: FontStyle.italic,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: TextEditingController(text: _customMathml),
              decoration: InputDecoration(
                labelText: l.equationCustom,
                hintText: '<math><mfrac><mn>1</mn><mn>2</mn></mfrac></math>',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              maxLines: 2,
              onChanged: (v) => _customMathml = v,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, EquationData(
            mathml: _customMathml.isNotEmpty ? _customMathml : _templates[_template]!,
            latex: _customMathml.isNotEmpty ? _customMathml : _templates[_template]!,
          )),
          child: Text(l.equationInsert),
        ),
      ],
    );
  }
}