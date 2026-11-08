import 'dart:io';
import '../models/package_type.dart';

class AtomicDirectoryManager {
  final String rootPackagesDir;

  const AtomicDirectoryManager({
    required this.rootPackagesDir,
  });

  Directory get stagingDir => Directory('$rootPackagesDir/staging');
  Directory get activeDir => Directory('$rootPackagesDir/active');
  Directory get backupDir => Directory('$rootPackagesDir/backup');

  Directory packageStagingDir(PackageType type) => Directory('${stagingDir.path}/${type.name}');
  Directory packageActiveDir(PackageType type) => Directory('${activeDir.path}/${type.name}');
  Directory packageBackupDir(PackageType type) => Directory('${backupDir.path}/${type.name}');

  File activeExecutable(PackageType type) =>
      File('${packageActiveDir(type).path}/${type.executableName}');

  /// Prepares an isolated, clean staging directory for an incoming download.
  Future<Directory> prepareStaging(PackageType type) async {
    final dir = packageStagingDir(type);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
    return dir.create(recursive: true);
  }

  /// Atomically swaps staging to active. If active already exists, it is moved to backup first.
  /// If staging activation fails, backup is restored immediately.
  Future<bool> commitStaging(PackageType type) async {
    final staging = packageStagingDir(type);
    final active = packageActiveDir(type);
    final backup = packageBackupDir(type);

    if (!await staging.exists()) {
      return false;
    }

    try {
      // 1. Move current active to backup if present
      if (await active.exists()) {
        if (await backup.exists()) {
          await backup.delete(recursive: true);
        }
        await backup.parent.create(recursive: true);
        await active.rename(backup.path);
      }

      // 2. Move staging to active
      await active.parent.create(recursive: true);
      await staging.rename(active.path);

      return true;
    } catch (e) {
      // Rollback on any failure
      if (await backup.exists() && !await active.exists()) {
        await backup.rename(active.path);
      }
      return false;
    }
  }

  /// Performs instant rollback to backup directory if active binary is corrupted.
  Future<bool> rollback(PackageType type) async {
    final active = packageActiveDir(type);
    final backup = packageBackupDir(type);

    if (!await backup.exists()) {
      return false;
    }

    try {
      if (await active.exists()) {
        await active.delete(recursive: true);
      }
      await backup.rename(active.path);
      return true;
    } catch (_) {
      return false;
    }
  }
}
