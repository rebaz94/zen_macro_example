import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:change_case/change_case.dart';
import 'package:macro_kit/macro_kit.dart';
import 'package:path/path.dart' as p;

enum LayoutType {
  stack,
  indexed,
}

/// Applied to individual route classes to collect metadata
class ZenLayoutMacro extends MacroGenerator {
  const ZenLayoutMacro({
    super.capability = zenLayoutMacroCapability,
    this.layoutType = LayoutType.indexed,
    this.routes = const [],
  });

  static ZenLayoutMacro initialize(MacroConfig config) {
    final props = Map.fromEntries(config.key.properties.map((e) => MapEntry(e.name, e)));

    return ZenLayoutMacro(
      capability: config.capability,
      layoutType: LayoutType.values.byName(
        props['layoutType']?.asStringConstantValue()?.split('.').lastOrNull ?? 'indexed',
      ),
    );
  }

  final LayoutType layoutType;
  final List<Type> routes;

  @override
  String get suffixName => 'Layout';

  @override
  GeneratedType get generatedType => GeneratedType.clazz;

  @override
  Future<void> onGenerate(MacroState state) async {
    // 1. Extract metadata from the class
    final className = state.targetName;
    final filePath = state.targetPath;

    // 2. Get the directory path (layouts represent their directory)
    final routesRoot = 'lib/routes';
    final relativePath = filePath.contains(routesRoot) ? filePath.split(routesRoot).last.substring(1) : filePath;

    final dirPath = p.dirname(relativePath);

    // 3. Load existing routes config
    final configFile = File('lib/routes/.routes_config.json');
    Map<String, dynamic> config = {};

    if (await configFile.exists()) {
      final content = await configFile.readAsString();
      config = json.decode(content) as Map<String, dynamic>;
    }

    // 4. Add/update this layout's data
    final layouts = config['layouts'] as List? ?? [];
    final layoutInfo = {
      'className': className,
      'filePath': relativePath,
      'directory': dirPath,
      'layoutType': layoutType.name,
      'routes': routes,
    };

    final existingIndex = layouts.indexWhere((l) => l['filePath'] == layoutInfo['filePath']);

    if (existingIndex >= 0) {
      layouts[existingIndex] = layoutInfo;
    } else {
      layouts.add(layoutInfo);
    }

    config['layouts'] = layouts;
    config['lastUpdate'] = DateTime.now().toIso8601String();

    // 5. Write back to config file
    await configFile.create(recursive: true);
    await configFile.writeAsString(JsonEncoder.withIndent('  ').convert(config));

    // 6. Generate the layout class
    final pathName = _pathNameFromDirectory(dirPath);

    final buff = StringBuffer();
    final generatedClass = '$className$suffixName';

    buff.write('abstract class $generatedClass extends AppRoute with RouteLayout<AppRoute> {\n');
    buff.write('  $generatedClass();\n\n');

    // Override resolvePath based on layout type
    buff.write('  @override\n');
    if (layoutType == LayoutType.indexed) {
      buff.write('  IndexedStackPath<AppRoute> resolvePath(\n');
    } else {
      buff.write('  NavigationPath<AppRoute> resolvePath(\n');
    }
    buff.write('    covariant AppCoordinator coordinator,\n');
    final name = '$pathName path'.toCamelCase();
    buff.write('  ) => coordinator.$name;\n');

    buff.write('}\n');

    state.reportGenerated(buff.toString(), canBeCombined: false);
  }

  String _pathNameFromDirectory(String dirPath) {
    // Convert directory path to camelCase path name
    // e.g., . -> root, tabs -> tabs, user/profile -> userProfile
    if (dirPath == '.') return 'root';

    final segments = p.split(dirPath).where((s) => s.isNotEmpty && !s.startsWith('(') && !s.startsWith('[')).toList();

    if (segments.isEmpty) return 'root';

    // First segment lowercase, rest capitalize first letter
    final pathName = segments.first + segments.skip(1).map((s) => s[0].toUpperCase() + s.substring(1)).join();

    return pathName;
  }
}

const zenLayoutMacro = Macro(
  ZenLayoutMacro(
    capability: zenLayoutMacroCapability,
  ),
);

const zenLayoutMacroCapability = MacroCapability(
  classConstructors: true,
);
