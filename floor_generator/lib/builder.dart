import 'package:build/build.dart';
import 'package:floor_generator/enum_helper_generator.dart';
import 'package:floor_generator/generator.dart';
import 'package:floor_generator/schema_generator.dart';
import 'package:source_gen/source_gen.dart';

/// This triggers the code generation process.
///
/// Use 'flutter packages pub run build_runner build' to start code generation.
///
/// Use 'flutter packages pub run build_runner watch' to trigger
/// code generation on changes.
Builder floorBuilder(final BuilderOptions _) =>
    SharedPartBuilder([FloorGenerator(), EnumHelperGenerator(), SchemaGenerator()], 'floor');
