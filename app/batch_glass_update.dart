import 'dart:io';

/// Batch adds backgroundColor: Colors.transparent to Scaffolds 
/// that have NatureBackground but no transparent background.
void main() {
  final dir = Directory(r'C:\Users\ganap\.gemini\antigravity-ide\scratch\horizon_travel\lib\screens');
  
  final dartFiles = dir.listSync(recursive: true)
      .where((f) => f.path.endsWith('_screen.dart'))
      .cast<File>();
  
  int modified = 0;
  
  for (final file in dartFiles) {
    var content = file.readAsStringSync();
    
    // Only update files that have NatureBackground but NOT transparent background
    if (!content.contains('NatureBackground')) continue;
    if (content.contains('Colors.transparent')) continue;
    
    // Pattern: Scaffold(\n      body: Stack( without transparent background
    final oldPattern = 'return Scaffold(\n      body: Stack(';
    if (content.contains(oldPattern)) {
      content = content.replaceFirst(
        oldPattern,
        'return Scaffold(\n      backgroundColor: Colors.transparent,\n      body: Stack(',
      );
      file.writeAsStringSync(content);
      modified++;
      print('Updated: ${file.path}');
    }
  }
  
  print('\nTotal files modified: $modified');
}
