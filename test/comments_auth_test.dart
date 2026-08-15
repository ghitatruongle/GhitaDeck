import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_ppt_converter/models/comment.dart';
import 'package:ghita_ppt_converter/models/user_profile.dart';
import 'package:ghita_ppt_converter/services/auth_service.dart';
import 'package:ghita_ppt_converter/services/comment_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('T48 — Comment model', () {
    test('round-trips through JSON', () {
      final c = Comment(
        id: 'c_abc123',
        slideIndex: 2,
        text: 'Xin chào thế giới!',
        authorName: 'Lan',
        authorColor: '#FF5722',
        createdAt: DateTime.utc(2026, 8, 15, 10, 30),
        replyTo: 'c_parent',
        anchor: 'p:nth-of-type(2)',
      );
      final restored = Comment.fromJson(c.toJson());
      expect(restored.id, c.id);
      expect(restored.slideIndex, 2);
      expect(restored.text, 'Xin chào thế giới!');
      expect(restored.authorName, 'Lan');
      expect(restored.authorColor, '#FF5722');
      expect(restored.replyTo, 'c_parent');
      expect(restored.anchor, 'p:nth-of-type(2)');
      expect(restored.createdAt.isUtc, isTrue);
      expect(restored.createdAt, c.createdAt);
    });

    test('handles malformed JSON gracefully', () {
      final c = Comment.fromJson('{not json');
      expect(c.id, '');
      expect(c.text, '');
    });

    test('copyWith updates text and resolution', () {
      final c = Comment(
        id: 'c_1',
        slideIndex: 0,
        text: 'a',
        authorName: 'A',
        authorColor: '#000000',
        createdAt: DateTime(2026, 1, 1),
      );
      final updated = c.copyWith(text: 'b', resolved: true);
      expect(updated.text, 'b');
      expect(updated.resolved, isTrue);
      expect(updated.id, 'c_1');
    });
  });

  group('T48 — CommentService', () {
    test('add/list/update/resolve/remove on a slide map', () {
      final slide = <String, dynamic>{
        'index': 0,
        'title': 'S',
        'htmlContent': '<p>x</p>',
      };
      final c1 = CommentService.addComment(slide,
          text: 'First', authorName: 'Lan', authorColor: '#FF5722');
      final c2 = CommentService.addComment(slide,
          text: 'Reply to first',
          authorName: 'Minh',
          authorColor: '#2196F3',
          replyTo: c1.id);

      expect(CommentService.countFor(slide), 2);
      expect(CommentService.commentsFor(slide), hasLength(2));
      expect(CommentService.commentsFor(slide).last.replyTo, c1.id);

      final updated = CommentService.updateComment(slide, c1.id, text: 'Edit');
      expect(updated!.text, 'Edit');
      expect(CommentService.setResolved(slide, c2.id, true), isTrue);
      expect(
          CommentService.commentsFor(slide)
              .firstWhere((c) => c.id == c2.id)
              .resolved,
          isTrue);
      expect(CommentService.removeComment(slide, c1.id), isTrue);
      expect(CommentService.countFor(slide), 1);
    });

    test('extracts unique @mentions', () {
      expect(CommentService.mentionsIn('@Lan please review @Minh too @Lan'),
          ['Lan', 'Minh']);
      expect(CommentService.mentionsIn('no mentions here'), isEmpty);
      expect(CommentService.mentionsIn('@Nguyễn_Văn test'), ['Nguyễn_Văn']);
    });

    test('dangling mentions filtered to known collaborators', () {
      final comments = [
        Comment(
          id: 'c_1',
          slideIndex: 0,
          text: '@Lan check this',
          authorName: 'M',
          authorColor: '#000',
          createdAt: DateTime(2026, 1, 1),
        ),
        Comment(
          id: 'c_2',
          slideIndex: 0,
          text: '@Ghost nobody here',
          authorName: 'M',
          authorColor: '#000',
          createdAt: DateTime(2026, 1, 1),
        ),
      ];
      final kept = CommentService.filterMentionsToKnown(
          comments, {'Lan'});
      expect(kept.map((c) => c.id), ['c_1']);
    });

    test('generates OOXML comment list and author list', () {
      final comments = [
        Comment(
          id: 'c_0000000000000001',
          slideIndex: 0,
          text: 'Sửa giúp em slide này',
          authorName: 'Lan',
          authorColor: '#FF5722',
          createdAt: DateTime(2026, 8, 15, 10, 30),
        ),
      ];
      final xml = CommentService.commentListXml(comments, '#FF5722');
      expect(xml, contains('<p:cmLst'));
      expect(xml, contains('Sửa giúp em slide này'));
      expect(xml, contains('<p:cm authorId="0"'));
      expect(xml, contains('<p14:threadingInfo'));
      final authors = CommentService.authorListXml('Lan', '#FF5722');
      expect(authors, contains('<p:cmAuthor id="0" name="Lan"'));
      expect(authors, contains('color="#FF5722"'));
    });
  });

  group('T49 — UserProfile & AuthService', () {
    test('profile round-trips and persists to SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      const p = UserProfile(
          name: 'Nguyễn Lan', avatarEmoji: '🌸', color: '#E91E63');
      await p.save();
      final loaded = await UserProfile.load();
      expect(loaded.name, 'Nguyễn Lan');
      expect(loaded.avatarEmoji, '🌸');
      expect(loaded.color, '#E91E63');
    });

    test('default profile loads when nothing stored', () async {
      SharedPreferences.setMockInitialValues({});
      final p = await UserProfile.load();
      expect(p.name, 'User');
      expect(p.avatarEmoji, '👤');
    });

    test('role helpers and tokens', () {
      expect(AuthService.canEdit('host'), isTrue);
      expect(AuthService.canEdit('editor'), isTrue);
      expect(AuthService.canEdit('viewer'), isFalse);
      expect(AuthService.isViewer('viewer'), isTrue);
      expect(AuthService.isViewer('editor'), isFalse);

      final editToken = AuthService.mintToken('editor');
      final viewToken = AuthService.mintToken('viewer');
      expect(AuthService.roleOfToken(editToken), 'editor');
      expect(AuthService.roleOfToken(viewToken), 'viewer');
      expect(AuthService.roleOfToken('garbage'), isNull);
      expect(AuthService.describe('viewer'), contains('Read-only'));
    });

    test('profile color normalises to a 6-digit hex', () {
      expect(AuthService.profileColor(const UserProfile(color: 'ff0000')),
          '#FF0000');
      expect(AuthService.profileColor(const UserProfile(color: 'bad')),
          '#FF9800');
    });
  });
}
