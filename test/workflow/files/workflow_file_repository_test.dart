import 'dart:io';

import 'package:ai_workflow_manager/workflow/files/workflow_file_access_event.dart';
import 'package:ai_workflow_manager/workflow/files/workflow_file_reference.dart';
import 'package:ai_workflow_manager/workflow/files/workflow_file_repository.dart';
import 'package:ai_workflow_manager/workflow/files/workflow_file_roots.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

void main() {
  late Directory testDirectory;
  late WorkflowFileRoots roots;
  late WorkflowFileRepository repository;
  late List<WorkflowFileAccessEvent> events;

  setUp(() {
    testDirectory = Directory.systemTemp.createTempSync(
      'workflow_file_repository_test_',
    );

    roots = WorkflowFileRoots(
      source: Directory(
        path.join(
          testDirectory.path,
          'source',
        ),
      )..createSync(),
      working: Directory(
        path.join(
          testDirectory.path,
          'working',
        ),
      )..createSync(),
      persistent: Directory(
        path.join(
          testDirectory.path,
          'persistent',
        ),
      )..createSync(),
    );

    events = [];

    repository = WorkflowFileRepository(
      roots: roots,
      nodeId: 'test-node',
      nodeExecutionId: 'test-execution-1',
      onEvent: (event) {
        events.add(event);
      },
    );
  });

  tearDown(() {
    if (testDirectory.existsSync()) {
      testDirectory.deleteSync(
        recursive: true,
      );
    }
  });

  group('exists', () {
    test('returns false for a missing file', () async {
      const reference = WorkflowFileReference(
        storage: WorkflowStorage.working,
        relativePath: 'missing.txt',
        format: WorkflowFileFormat.plainText,
      );

      final result = await repository.exists(
        reference,
      );

      expect(result, isFalse);

      expect(
        events.map((event) => event.phase),
        [
          WorkflowFileAccessPhase.started,
          WorkflowFileAccessPhase.completed,
        ],
      );

      expect(
        events.last.operation,
        WorkflowFileOperation.inspect,
      );

      expect(
        events.last.exists,
        isFalse,
      );
    });
  });

  group('readText', () {
    test('reads UTF-8 source content', () async {
      final sourceFile = File(
        path.join(
          roots.source.path,
          'input.md',
        ),
      );

      await sourceFile.writeAsString(
        'Hello. Grüße aus Aachen.',
      );

      const reference = WorkflowFileReference(
        storage: WorkflowStorage.source,
        relativePath: 'input.md',
        format: WorkflowFileFormat.markdown,
      );

      final content = await repository.readText(
        reference,
      );

      expect(
        content,
        'Hello. Grüße aus Aachen.',
      );

      expect(
        events.map((event) => event.phase),
        [
          WorkflowFileAccessPhase.started,
          WorkflowFileAccessPhase.completed,
        ],
      );

      expect(
        events.last.operation,
        WorkflowFileOperation.read,
      );

      expect(
        events.last.sizeBytes,
        greaterThan(0),
      );
    });

    test('reports a missing file', () async {
      const reference = WorkflowFileReference(
        storage: WorkflowStorage.source,
        relativePath: 'missing.md',
        format: WorkflowFileFormat.markdown,
      );

      await expectLater(
        repository.readText(reference),
        throwsA(
          isA<WorkflowFileAccessException>().having(
            (exception) => exception.message,
            'message',
            allOf(
              contains('missing.md'),
              contains('does not exist'),
            ),
          ),
        ),
      );

      expect(
        events.map((event) => event.phase),
        [
          WorkflowFileAccessPhase.started,
          WorkflowFileAccessPhase.failed,
        ],
      );
    });

    test('rejects a path that escapes its root', () async {
      const reference = WorkflowFileReference(
        storage: WorkflowStorage.source,
        relativePath: '../outside.md',
        format: WorkflowFileFormat.markdown,
      );

      await expectLater(
        repository.readText(reference),
        throwsA(
          isA<WorkflowFileAccessException>().having(
            (exception) => exception.message,
            'message',
            contains('escapes the source directory'),
          ),
        ),
      );
    });

    test('rejects an absolute path', () async {
      final reference = WorkflowFileReference(
        storage: WorkflowStorage.source,
        relativePath: path.join(
          testDirectory.absolute.path,
          'outside.md',
        ),
        format: WorkflowFileFormat.markdown,
      );

      await expectLater(
        repository.readText(reference),
        throwsA(
          isA<WorkflowFileAccessException>().having(
            (exception) => exception.message,
            'message',
            contains('must be relative'),
          ),
        ),
      );
    });
  });

  group('writeText', () {
    test('creates parent directories and writes a file', () async {
      const reference = WorkflowFileReference(
        storage: WorkflowStorage.working,
        relativePath: 'prepared/context.md',
        format: WorkflowFileFormat.markdown,
      );

      await repository.writeText(
        reference,
        '# Context\n',
      );

      final writtenFile = File(
        path.join(
          roots.working.path,
          'prepared',
          'context.md',
        ),
      );

      expect(
        await writtenFile.readAsString(),
        '# Context\n',
      );

      expect(
        events.last.phase,
        WorkflowFileAccessPhase.completed,
      );

      expect(
        events.last.operation,
        WorkflowFileOperation.write,
      );

      expect(
        events.last.replacedExisting,
        isFalse,
      );
    });

    test('replaces an existing persistent file', () async {
      final existingFile = File(
        path.join(
          roots.persistent.path,
          'summary.txt',
        ),
      );

      await existingFile.writeAsString(
        'Old content',
      );

      const reference = WorkflowFileReference(
        storage: WorkflowStorage.persistent,
        relativePath: 'summary.txt',
        format: WorkflowFileFormat.plainText,
      );

      await repository.writeText(
        reference,
        'New content',
      );

      expect(
        await existingFile.readAsString(),
        'New content',
      );

      expect(
        events.last.replacedExisting,
        isTrue,
      );
    });

    test('rejects writes to source storage', () async {
      const reference = WorkflowFileReference(
        storage: WorkflowStorage.source,
        relativePath: 'source.md',
        format: WorkflowFileFormat.markdown,
      );

      await expectLater(
        repository.writeText(
          reference,
          'Attempted modification',
        ),
        throwsA(
          isA<WorkflowFileAccessException>().having(
            (exception) => exception.message,
            'message',
            contains('Source files are read-only'),
          ),
        ),
      );

      final sourceFile = File(
        path.join(
          roots.source.path,
          'source.md',
        ),
      );

      expect(
        await sourceFile.exists(),
        isFalse,
      );

      expect(
        events.map((event) => event.phase),
        [
          WorkflowFileAccessPhase.started,
          WorkflowFileAccessPhase.failed,
        ],
      );
    });
  });

  group('JSON', () {
    test('writes and reads structured JSON', () async {
      const reference = WorkflowFileReference(
        storage: WorkflowStorage.working,
        relativePath: 'state/counter.json',
        format: WorkflowFileFormat.json,
      );

      await repository.writeJson(
        reference,
        {
          'count': 4,
          'continue': true,
        },
      );

      final value = await repository.readJson(
        reference,
      );

      expect(
        value,
        {
          'count': 4,
          'continue': true,
        },
      );
    });

    test('rejects readJson for a non-JSON reference', () async {
      const reference = WorkflowFileReference(
        storage: WorkflowStorage.working,
        relativePath: 'notes.md',
        format: WorkflowFileFormat.markdown,
      );

      await expectLater(
        repository.readJson(reference),
        throwsA(
          isA<WorkflowFileAccessException>().having(
            (exception) => exception.message,
            'message',
            contains('not JSON'),
          ),
        ),
      );
    });

    test('reports invalid JSON content', () async {
      final invalidFile = File(
        path.join(
          roots.working.path,
          'invalid.json',
        ),
      );

      await invalidFile.writeAsString(
        '{"count": }',
      );

      const reference = WorkflowFileReference(
        storage: WorkflowStorage.working,
        relativePath: 'invalid.json',
        format: WorkflowFileFormat.json,
      );

      await expectLater(
        repository.readJson(reference),
        throwsA(
          isA<WorkflowFileAccessException>().having(
            (exception) => exception.message,
            'message',
            contains('contains invalid JSON'),
          ),
        ),
      );
    });
  });

  if (!Platform.isWindows) {
    test('rejects symbolic-link traversal', () async {
      final outsideDirectory = Directory(
        path.join(
          testDirectory.path,
          'outside',
        ),
      )..createSync();

      final outsideFile = File(
        path.join(
          outsideDirectory.path,
          'private.txt',
        ),
      );

      await outsideFile.writeAsString(
        'Private content',
      );

      final link = Link(
        path.join(
          roots.source.path,
          'linked-directory',
        ),
      );

      await link.create(
        outsideDirectory.path,
      );

      const reference = WorkflowFileReference(
        storage: WorkflowStorage.source,
        relativePath: 'linked-directory/private.txt',
        format: WorkflowFileFormat.plainText,
      );

      await expectLater(
        repository.readText(reference),
        throwsA(
          isA<WorkflowFileAccessException>().having(
            (exception) => exception.message,
            'message',
            contains('contains a symbolic link'),
          ),
        ),
      );
    });
  }
}