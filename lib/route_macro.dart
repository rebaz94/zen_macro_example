import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:macro_kit/macro_kit.dart';
import 'package:path/path.dart' as p;
export 'package:zenrouter/zenrouter.dart';


/// Applied to individual route classes to collect metadata
class ZenRouteMacro extends MacroGenerator {
  const ZenRouteMacro({
    super.capability = zenRouteMacroCapability,
  });

  static ZenRouteMacro initialize(MacroConfig config) {
    return ZenRouteMacro(
      capability: config.capability,
    );
  }

  @override
  String get suffixName => 'Route';

  @override
  GeneratedType get generatedType => GeneratedType.clazz;

  @override
  Future<void> onGenerate(MacroState state) async {
    // 1. Extract metadata from the class
    final className = state.targetName;
    final filePath = state.targetPath; // Full path to current file

    // 2. Determine position in route tree
    final routeInfo = _extractRouteInfo(filePath, className);

    // 3. Load existing routes config
    final configFile = File('lib/routes/.routes_config.json');
    Map<String, dynamic> config = {};

    if (await configFile.exists()) {
      final content = await configFile.readAsString();
      config = json.decode(content) as Map<String, dynamic>;
    }

    // 4. Add/update this route's data
    final routes = config['routes'] as List? ?? [];
    final existingIndex = routes.indexWhere((r) => r['filePath'] == routeInfo['filePath']);

    if (existingIndex >= 0) {
      routes[existingIndex] = routeInfo;
    } else {
      routes.add(routeInfo);
    }

    final routePath = routeInfo['routePath'] as String;
    config['routes'] = routes;
    config['lastUpdate'] = DateTime.now().toIso8601String();

    // 5. Write back to config file
    await configFile.create(recursive: true);
    await configFile.writeAsString(JsonEncoder.withIndent('  ').convert(config));

    // 6. Extract dynamic parameters from route path
    final dynamicParams = _extractDynamicParams(routePath);

    final buff = StringBuffer();
    final generatedClass = '$className${state.suffixName}';

    buff.write('abstract class $generatedClass extends AppRoute {\n');

    // Constructor with dynamic parameters
    if (dynamicParams.isNotEmpty) {
      buff.write('  $generatedClass({\n');
      for (final param in dynamicParams) {
        // Catch-all params are List<String>, others are String
        buff.write('    required this.${param.name},\n');
      }
      buff.write('  });\n\n');

      // Field declarations
      for (final param in dynamicParams) {
        final type = param.isCatchAll ? 'List<String>' : 'String';
        buff.write('  final $type ${param.name};\n');
      }
      buff.write('\n');
    } else {
      buff.write('  $generatedClass();\n\n');
    }

    // toUri method with interpolated parameters
    buff.write('  Uri toUri() => ');
    if (dynamicParams.isEmpty) {
      buff.write("Uri.parse('$routePath');\n");
    } else {
      // Build the path with interpolation
      var path = routePath;
      for (final param in dynamicParams) {
        if (param.isCatchAll) {
          // Replace *param with joined list
          path = path.replaceAll('*${param.name}', '\${${param.name}.join(\'/\')}');
        } else {
          // Replace :param with field value
          path = path.replaceAll(':${param.name}', '\$${param.name}');
        }
      }
      buff.write('Uri.parse(\'$path\');\n');
    }

    buff.writeln();

    // props getter for equality
    buff.write('  List<Object?> get props => [');
    if (dynamicParams.isNotEmpty) {
      buff.write(dynamicParams.map((p) => p.name).join(', '));
    }
    buff.write('];\n');

    buff.write('}\n');

    state.reportGenerated(buff.toString(), canBeCombined: false);
  }

  Map<String, dynamic> _extractRouteInfo(String filePath, String className) {
    // Convert absolute path to relative from lib/routes/
    final routesRoot = 'lib/routes';
    final relativePath = filePath.contains(routesRoot) ? filePath.split(routesRoot).last.substring(1) : filePath;

    // Get the directory path and filename separately
    final dirPath = p.dirname(relativePath);
    final fileName = p.basenameWithoutExtension(filePath);

    // Parse directory structure (without the filename)
    final segments = dirPath == '.' ? <String>[] : p.split(dirPath);

    // Detect file type
    final detectedType = _detectRouteType(fileName);

    // Build route path based on directory + filename
    final routePath = _buildRoutePath(segments, fileName);

    // Check for dynamic segments
    final isDynamic =
        segments.any((s) => s.startsWith('[') && s.endsWith(']')) ||
        (fileName.startsWith('[') && fileName.endsWith(']'));
    final isCatchAll =
        segments.any((s) => s.startsWith('[...') || s.startsWith('[[...')) || fileName.startsWith('[...');
    final isRouteGroup = segments.any((s) => s.startsWith('(') && s.endsWith(')'));

    return {
      'className': className,
      'filePath': relativePath,
      'routeType': detectedType,
      'routePath': routePath,
      'segments': segments,
      'fileName': fileName,
      'isDynamic': isDynamic,
      'isCatchAll': isCatchAll,
      'isRouteGroup': isRouteGroup,
    };
  }

  String _detectRouteType(String fileName) {
    return switch (fileName) {
      'page' => 'page',
      'layout' => 'layout',
      'loading' => 'loading',
      'error' => 'error',
      'not_found' => 'not_found',
      _ => 'page',
    };
  }

  String _buildRoutePath(List<String> segments, String fileName) {
    final pathSegments = <String>[];

    // Process directory segments
    for (final segment in segments) {
      // Skip route groups
      if (segment.startsWith('(') && segment.endsWith(')')) {
        continue;
      }

      // Convert dynamic segments
      if (segment.startsWith('[') && segment.endsWith(']')) {
        final param = segment.substring(1, segment.length - 1);

        // Handle catch-all
        if (param.startsWith('...')) {
          pathSegments.add('*${param.substring(3)}'); // [...slug] -> *slug
        } else if (param.startsWith('[...')) {
          pathSegments.add('*${param.substring(4, param.length - 1)}'); // [[...slug]] -> *slug
        } else {
          pathSegments.add(':$param'); // [id] -> :id
        }
      } else {
        pathSegments.add(segment);
      }
    }

    // Process filename (skip if it's index, page, layout, loading, error, or not_found)
    final specialFiles = {'index', 'page', 'layout', 'loading', 'error', 'not_found'};

    if (!specialFiles.contains(fileName)) {
      // Regular file becomes a route segment
      if (fileName.startsWith('[') && fileName.endsWith(']')) {
        final param = fileName.substring(1, fileName.length - 1);

        // Handle catch-all in filename
        if (param.startsWith('...')) {
          pathSegments.add('*${param.substring(3)}');
        } else if (param.startsWith('[...')) {
          pathSegments.add('*${param.substring(4, param.length - 1)}');
        } else {
          pathSegments.add(':$param');
        }
      } else {
        pathSegments.add(fileName);
      }
    }

    // Build final path
    if (pathSegments.isEmpty) {
      return '/';
    }

    return '/${pathSegments.join('/')}';
  }

  List<_DynamicParam> _extractDynamicParams(String routePath) {
    final params = <_DynamicParam>[];
    final segments = routePath.split('/').where((s) => s.isNotEmpty).toList();

    for (final segment in segments) {
      if (segment.startsWith(':')) {
        // Regular dynamic parameter like :id
        params.add(
          _DynamicParam(
            name: segment.substring(1),
            isCatchAll: false,
          ),
        );
      } else if (segment.startsWith('*')) {
        // Catch-all parameter like *slug
        params.add(
          _DynamicParam(
            name: segment.substring(1),
            isCatchAll: true,
          ),
        );
      }
    }

    return params;
  }
}

class _DynamicParam {
  final String name;
  final bool isCatchAll;

  _DynamicParam({
    required this.name,
    required this.isCatchAll,
  });
}

const zenRouteMacro = Macro(
  ZenRouteMacro(
    capability: zenRouteMacroCapability,
  ),
);

const zenRouteMacroCapability = MacroCapability(
  classConstructors: true,
);
