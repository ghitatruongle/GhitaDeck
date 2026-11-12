import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_deck/providers/presentation_state.dart';
import 'package:ghita_deck/services/template_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('applyTheme replaces all placeholder kinds', () {
    const html =
        '<h1 style="color:{primary}">{font}</h1><p>{accent} {font-family} {unknown}</p>';
    final out = TemplateService.applyTheme(html,
        primary: '#111111', accent: '#222222', font: 'Arial');
    expect(out.contains('#111111'), isTrue);
    expect(out.contains('#222222'), isTrue);
    expect(out.contains('Arial'), isTrue);
    expect(out.contains('{unknown}'), isTrue);
    expect(TemplateService.applyTheme(html), contains('#1F4E79'));
    expect(TemplateService.applyTheme(html), contains('#ED7D31'));
  });

  test('templateFromDeck parametrizes colors of first slide html', () {
    final state = PresentationState();
    state.addSlide(
        Slide(title: 'T', htmlContent: '<h1 style="color:#1F4E79">Hi</h1>'));
    final template = TemplateService.templateFromDeck(state, name: 'Mine');
    expect(template.name, 'Mine');
    expect(template.htmlContent.contains('{primary}'), isTrue);
    expect(template.htmlContent.contains('#1F4E79'), isFalse);
    expect(template.category, 'User');
    state.dispose();
  });

  test('templateFromDeck falls back to placeholder html on empty deck', () {
    final state = PresentationState();
    final template = TemplateService.templateFromDeck(state);
    expect(template.htmlContent.contains('<h1>'), isTrue);
    state.dispose();
  });

  test('templateFromDeck honors explicit accent color', () {
    final state = PresentationState();
    final template = TemplateService.templateFromDeck(state,
        accent: const Color(0xFF00FF00));
    expect(template.accentColor, const Color(0xFF00FF00));
    state.dispose();
  });
}
