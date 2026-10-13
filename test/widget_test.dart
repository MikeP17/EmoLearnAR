import 'package:emolearnar/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('EmoLearnAR home screen smoke test', (tester) async {
    await tester.pumpWidget(const EmoLearnARApp());
    await tester.pump();

    expect(find.text('EmoLearnAR'), findsOneWidget);
    expect(find.text('Start Session'), findsOneWidget);
  });
}
