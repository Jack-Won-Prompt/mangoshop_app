import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangoshop_app/models/models.dart';
import 'package:mangoshop_app/widgets/common.dart';

/// 카테고리 아이콘이 무엇을 보여 주는지 확인한다.
///
/// 예전에는 icon 에 든 값을 그대로 글자로 찍어서, 'cat-citrus' 가 들어오면
/// 화면에 "cat-citru" 라는 글자가 그냥 보였다. 그 일이 되풀이되지 않는지 본다.
void main() {
  Future<void> show(WidgetTester tester, Widget w) =>
      tester.pumpWidget(MaterialApp(home: Scaffold(body: Center(child: w))));

  testWidgets('이모지는 글자로 보여 준다', (tester) async {
    await show(tester, const CategoryIcon('🍊'));
    expect(find.text('🍊'), findsOneWidget);
    expect(find.byType(Icon), findsNothing);
  });

  testWidgets('영문 키는 글자로 찍지 않고 기본 아이콘으로 대체한다', (tester) async {
    for (final key in ['cat-citrus', 'cat-mango', 'box', 'grid_2']) {
      await show(tester, CategoryIcon(key));
      expect(find.text(key), findsNothing, reason: '$key 가 글자로 보입니다');
      expect(find.byType(Icon), findsOneWidget, reason: '$key 에서 기본 아이콘이 없습니다');
    }
  });

  testWidgets('비어 있으면 기본 아이콘을 보여 준다', (tester) async {
    await show(tester, const CategoryIcon(null));
    expect(find.byType(Icon), findsOneWidget);

    await show(tester, const CategoryIcon('   '));
    expect(find.byType(Icon), findsOneWidget);
  });

  testWidgets('그림이 있으면 그림이 이모지보다 앞선다', (tester) async {
    await show(tester, const CategoryIcon('🍊', image: 'https://example.test/jeju.png'));
    expect(find.text('🍊'), findsNothing);
    expect(find.byType(ClipOval), findsOneWidget);
  });

  testWidgets('그림 주소가 비어 있으면 이모지로 돌아간다', (tester) async {
    await show(tester, const CategoryIcon('🍊', image: '   '));
    expect(find.text('🍊'), findsOneWidget);
  });

  test('서버가 준 image 를 모델이 받아 둔다', () {
    final c = Category.fromJson({
      'id': 26,
      'name': '제주도 과일',
      'slug': 'jeju',
      'icon': '🍊',
      'image': 'https://mangoshop.co.kr/storage/uploads/categories/jeju.png',
      'children': [],
    });
    expect(c.image, 'https://mangoshop.co.kr/storage/uploads/categories/jeju.png');
    expect(c.icon, '🍊');
  });

  test('image 가 없던 예전 응답도 그대로 읽힌다', () {
    final c = Category.fromJson({'id': 1, 'name': '망고', 'slug': 'mango', 'icon': '🥭'});
    expect(c.image, isNull);
    expect(c.name, '망고');
  });
}
