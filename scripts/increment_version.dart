import 'dart:io';

void main() {
  final pubspec = File('pubspec.yaml');

  if (!pubspec.existsSync()) {
    print('Error: pubspec.yaml not found');
    exit(1);
  }

  var content = pubspec.readAsStringSync();

  final versionRegex = RegExp(r'version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)');
  final match = versionRegex.firstMatch(content);

  if (match != null) {
    final major = int.parse(match.group(1)!);
    final minor = int.parse(match.group(2)!);
    final patch = int.parse(match.group(3)!);
    final build = int.parse(match.group(4)!) + 1;

    final newVersion = '$major.$minor.$patch+$build';
    content = content.replaceFirst(versionRegex, 'version: $newVersion');

    pubspec.writeAsStringSync(content);
    print('Version incremented to $newVersion');
  } else {
    // Handle version without build number (e.g., "1.0.7")
    final simpleVersionRegex = RegExp(r'version:\s*(\d+)\.(\d+)\.(\d+)\s*$', multiLine: true);
    final simpleMatch = simpleVersionRegex.firstMatch(content);

    if (simpleMatch != null) {
      final major = int.parse(simpleMatch.group(1)!);
      final minor = int.parse(simpleMatch.group(2)!);
      final patch = int.parse(simpleMatch.group(3)!);
      final build = 1; // Start build number at 1

      final newVersion = '$major.$minor.$patch+$build';
      content = content.replaceFirst(simpleVersionRegex, 'version: $newVersion');

      pubspec.writeAsStringSync(content);
      print('Version incremented to $newVersion (added build number)');
    } else {
      print('Error: Could not find version in pubspec.yaml');
      exit(1);
    }
  }
}
