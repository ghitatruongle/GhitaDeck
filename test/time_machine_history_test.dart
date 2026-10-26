import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_deck/models/slide.dart';
import 'package:ghita_deck/services/time_machine_history_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TimeMachineHistoryService Tests', () {
    test('recordSnapshot and undo/redo navigation', () {
      final history = TimeMachineHistoryService();

      final slide1 = Slide(title: 'Slide 1', htmlContent: '<h1>1</h1>');
      history.recordSnapshot('Step 1', [slide1]);

      expect(history.canUndo, false);
      expect(history.canRedo, false);

      final slide2 = Slide(title: 'Slide 2', htmlContent: '<h1>2</h1>');
      history.recordSnapshot('Step 2', [slide1, slide2]);

      expect(history.canUndo, true);
      expect(history.canRedo, false);

      final previous = history.undo();
      expect(previous, isNotNull);
      expect(previous!.length, 1);
      expect(previous.first.title, 'Slide 1');
      expect(history.canRedo, true);

      final redone = history.redo();
      expect(redone, isNotNull);
      expect(redone!.length, 2);
      expect(history.canUndo, true);
    });
  });
}
