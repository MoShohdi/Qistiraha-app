// ignore_for_file: avoid_print
import 'dart:io';

void main() async {
  print('🦅 Starting Qistiraha Smart Migration Script...');

  // 1. Map out exactly where the files live right now vs where they go
  final fileMoveMap = {
    // Core Engine & Policies
    'lib/engine/affordability_engine.dart': 'lib/core/engine/affordability_engine.dart',
    'lib/engine/penalty_engine.dart': 'lib/core/engine/penalty_engine.dart',
    // Core Services
    'lib/services/hive_service.dart': 'lib/core/services/hive_service.dart',
    'lib/services/time_service.dart': 'lib/core/services/time_service.dart',
    'lib/services/mock_data_service.dart': 'lib/core/services/mock_data_service.dart',
    'lib/services/ai_advisor_service.dart': 'lib/core/services/ai_advisor_service.dart',
    // Auth Models & Services
    'lib/models/user_account.dart': 'lib/features/auth/models/user_account.dart',
    'lib/models/user_account.g.dart': 'lib/features/auth/models/user_account.g.dart',
    'lib/models/business_account.dart': 'lib/features/auth/models/business_account.dart',
    'lib/models/business_account.g.dart': 'lib/features/auth/models/business_account.g.dart',
    'lib/services/auth_service.dart': 'lib/features/auth/services/auth_service.dart',
    // Consumer Models & Controllers
    'lib/screens/consumer/add_installment_controller.dart': 'lib/features/consumer/controllers/add_installment_controller.dart',
    'lib/models/installment.dart': 'lib/features/consumer/models/installment.dart',
    'lib/models/installment.g.dart': 'lib/features/consumer/models/installment.g.dart',
    'lib/models/enums.dart': 'lib/features/consumer/models/enums.dart',
    'lib/models/late_fee_rule.dart': 'lib/features/consumer/models/late_fee_rule.dart',
    'lib/models/late_fee_rule.g.dart': 'lib/features/consumer/models/late_fee_rule.g.dart',
  };

  // 2. Safely move mapped files
  fileMoveMap.forEach((oldPath, newPath) {
    final oldFile = File(oldPath);
    if (oldFile.existsSync()) {
      File(newPath).createSync(recursive: true);
      oldFile.renameSync(newPath);
      print('✅ Moved: $oldPath ➡️ $newPath');
    }
  });

  // 3. Move wildcards from policies, auth, consumer, and merchant screen folders
  _moveDirectoryContents('lib/engine/policies', 'lib/core/engine/policies');
  _moveDirectoryContents('lib/screens/auth', 'lib/features/auth/screens');
  _moveDirectoryContents('lib/screens/consumer', 'lib/features/consumer/screens');
  _moveDirectoryContents('lib/screens/merchant', 'lib/features/merchant/screens');

  // 4. Smart Import Refactoring Strategy
  print('\n🔄 Refactoring broken relative imports into absolute package imports...');
  final libDir = Directory('lib');
  if (libDir.existsSync()) {
    await for (final file in libDir.list(recursive: true)) {
      if (file is File && file.path.endsWith('.dart') && !file.path.endsWith('.g.dart')) {
        _refactorImportsInFile(file);
      }
    }
  }

  // 5. Cleanup empty legacy directories
  _cleanupLegacyDirs(['lib/engine', 'lib/models', 'lib/screens', 'lib/services']);

  print('\n🏁 Migration fully complete! Run "flutter analyze" to verify details. 🦾');
}

void _moveDirectoryContents(String srcPath, String destPath) {
  final srcDir = Directory(srcPath);
  if (!srcDir.existsSync()) return;

  Directory(destPath).createSync(recursive: true);
  for (final entity in srcDir.listSync()) {
    if (entity is File) {
      final newFilePath = '$destPath/${entity.uri.pathSegments.last}';
      entity.renameSync(newFilePath);
      print('✅ Moved: ${entity.path} ➡️ $newFilePath');
    }
  }
}

void _refactorImportsInFile(File file) {
  String content = file.readAsStringSync();
  bool modified = false;

  // Simple and highly effective regex pattern to catch raw relative imports to our moving modules
  final relativeImportRegex = RegExp("import\\s+['\"](\\.\\./)+((models|services|engine)/[^'\"]+)['\"];");

  final matches = relativeImportRegex.allMatches(content);
  for (final match in matches) {
    final oldImport = match.group(0)!;
    final pathSuffix = match.group(2)!;
    
    // Convert relative mess into reliable absolute package imports
    String newPath = 'package:qistiraha/';
    if (pathSuffix.startsWith('engine/')) {
      newPath += 'core/$pathSuffix';
    } else if (pathSuffix.contains('user_account') || pathSuffix.contains('business_account') || pathSuffix.contains('auth_service')) {
      newPath += 'features/auth/$pathSuffix';
    } else {
      newPath += 'features/consumer/$pathSuffix';
    }

    final newImport = "import '$newPath';";
    content = content.replaceAll(oldImport, newImport);
    modified = true;
  }

  if (modified) {
    file.writeAsStringSync(content);
    print('⚙️ Refactored imports in: ${file.path}');
  }
}

void _cleanupLegacyDirs(List<String> dirs) {
  print('\n🗑️ Cleaning up legacy directory shells...');
  for (final dirPath in dirs) {
    final dir = Directory(dirPath);
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
      print('🧹 Removed empty directory: $dirPath');
    }
  }
}