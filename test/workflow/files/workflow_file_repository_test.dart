import 'dart:io';

import 'package:ai_workflow_manager/workflow/files/workflow_file_repository.dart';
import 'package:ai_workflow_manager/workflow/files/workflow_file_roots.dart';
import 'package:ai_workflow_manager/workflow/files/workflow_file_reference.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

void main() {
  late Directory testDirectory;
  late WorkflowFileRoots roots;
  late WorkflowFileRepository repository;

  setUp(() {
    testDirectory = Directory.systemTemp.createTempSync(
      'workflow_file_repository_test_',
    );

    roots = WorkflowFileRoots(
      source: Directory(
        path.join(testDirectory.path, 'source'),
      )..createSync(),
      working: Directory(
        path.join(testDirectory.path, 'working'),
      )..createSync(),
      persistent: Directory(
        path.join(testDirectory.path, 'persistent'),
      )..createSync(),
    );

    repository = WorkflowFileRepository(
      roots: roots,
    );
  });

  tearDown(() {
    if (testDirectory.existsSync()) {
      testDirectory.deleteSync(recursive: true);
    }
  });

  group('WorkflowFileRepository.resolve', () {
    test('resolves a file inside the working directory', () {
      const reference = WorkflowFileReference(
        storage: WorkflowStorage.working,
        relativePath: 'prepared/context.md',
        format: WorkflowFileFormat.markdown,
      );

      final file = repository.resolve(reference);

      final expectedPath = path.normalize(
        path.join(
          roots.working.absolute.path,
          'prepared/context.md',
        ),
      );

      expect(file.path, expectedPath);
    });

    test('uses the source root for source files', () {
      const reference = WorkflowFileReference(
        storage: WorkflowStorage.source,
        relativePath: 'documents/input.txt',
        format: WorkflowFileFormat.plainText,
      );

      final file = repository.resolve(reference);

      final expectedPath = path.normalize(
        path.join(
          roots.source.absolute.path,
          'documents/input.txt',
        ),
      );

      expect(file.path, expectedPath);
    });

    test('uses the persistent root for persistent files', () {
      const reference = WorkflowFileReference(
        storage: WorkflowStorage.persistent,
        relativePath: 'indexes/source-index.json',
        format: WorkflowFileFormat.json,
      );

      final file = repository.resolve(reference);

      final expectedPath = path.normalize(
        path.join(
          roots.persistent.absolute.path,
          'indexes/source-index.json',
        ),
      );

      expect(file.path, expectedPath);
    });

    test('normalizes path segments that remain inside the root', () {
      const reference = WorkflowFileReference(
        storage: WorkflowStorage.working,
        relativePath: 'prepared/drafts/../context.md',
        format: WorkflowFileFormat.markdown,
      );

      final file = repository.resolve(reference);

      final expectedPath = path.normalize(
        path.join(
          roots.working.absolute.path,
          'prepared/context.md',
        ),
      );

      expect(file.path, expectedPath);
    });

    test('rejects an empty relative path', () {
      const reference = WorkflowFileReference(
        storage: WorkflowStorage.working,
        relativePath: '',
        format: WorkflowFileFormat.plainText,
      );

      expect(
        () => repository.resolve(reference),
        throwsA(
          isA<WorkflowFileAccessException>().having(
            (exception) => exception.message,
            'message',
            contains('cannot be empty'),
          ),
        ),
      );
    });

    test('rejects a whitespace-only relative path', () {
      const reference = WorkflowFileReference(
        storage: WorkflowStorage.working,
        relativePath: '   ',
        format: WorkflowFileFormat.plainText,
      );

      expect(
        () => repository.resolve(reference),
        throwsA(
          isA<WorkflowFileAccessException>().having(
            (exception) => exception.message,
            'message',
            contains('cannot be empty'),
          ),
        ),
      );
    });

    test('rejects an absolute path', () {
      final absolutePath = path.join(
        testDirectory.absolute.path,
        'outside.txt',
      );

      final reference = WorkflowFileReference(
        storage: WorkflowStorage.working,
        relativePath: absolutePath,
        format: WorkflowFileFormat.plainText,
      );

      expect(
        () => repository.resolve(reference),
        throwsA(
          isA<WorkflowFileAccessException>().having(
            (exception) => exception.message,
            'message',
            contains('must be relative'),
          ),
        ),
      );
    });

    test('rejects a path that escapes the selected root', () {
      const reference = WorkflowFileReference(
        storage: WorkflowStorage.working,
        relativePath: '../outside.txt',
        format: WorkflowFileFormat.plainText,
      );

      expect(
        () => repository.resolve(reference),
        throwsA(
          isA<WorkflowFileAccessException>().having(
            (exception) => exception.message,
            'message',
            contains('escapes the working directory'),
          ),
        ),
      );
    });

    test('does not create the resolved file', () {
      const reference = WorkflowFileReference(
        storage: WorkflowStorage.working,
        relativePath: 'result.txt',
        format: WorkflowFileFormat.plainText,
      );

      final file = repository.resolve(reference);

      expect(file.existsSync(), isFalse);
    });
  });
}