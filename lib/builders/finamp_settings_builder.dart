import 'dart:async';

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import 'annotations.dart';

// This file is part of the build system and cannot be imported by any files
// within the actual app or the launch will fail while trying to import dart:mirrors
// It should also not import any non-builder classes to avoid importing dart:ui

Builder getFinampSettingsGenerator(BuilderOptions options) =>
    SharedPartBuilder([_FinampSettingsGenerator()], 'finamp_settings_builder');

/// Generate setters and providers for all fields in FinampSettings.  The generated
/// code is part of finamp_settings_helper.dart.  Fields annotated with
/// @FinampSetterIgnore() are ignored.
class _FinampSettingsGenerator extends Generator {
  @override
  FutureOr<String> generate(LibraryReader library, BuildStep buildStep) async {
    if (library.findType("FinampSettingsHelper") == null) {
      return '';
    }
    ClassElement? settings;
    for (var import in library.element.definingCompilationUnit.libraryImports) {
      settings = LibraryReader(import.importedLibrary!).findType("FinampSettings");
      if (settings != null) break;
    }
    if (settings == null) {
      log.warning("Could not find FinampSettings");
      return '';
    }

    var settersCode = "";
    var selectorsCode = "";
    for (var property in settings.accessors) {
      if (!property.nonSynthetic.hasDeprecated &&
          TypeChecker.fromRuntime(SettingsHelperIgnore).firstAnnotationOfExact(property.nonSynthetic) == null) {
        final mapAnnotationObj = TypeChecker.fromRuntime(
          SettingsHelperMap,
        ).firstAnnotationOfExact(property.nonSynthetic);

        if (property.isSetter) {
          if (property.parameters.length != 1) {
            log.warning("Unexpected param count for ${property.displayName}: ${property.parameters.length}");
          }
          var typeArg = property.parameters.first.type;
          // setter name with first letter uppercase for adding prefixes to
          var paramName = "${property.displayName.substring(0, 1).toUpperCase()}${property.displayName.substring(1)}";

          if (mapAnnotationObj != null) {
            if (!typeArg.isDartCoreMap) {
              throw "Error on FinampSettings.${property.displayName} - Non-Maps cannot have SettingsHelperMap annotation.";
            }
            final mapAnnotation = SettingsHelperMap.fromRaw(mapAnnotationObj);
            final mapType = typeArg as ParameterizedType;
            final keyType = _typeName(mapType.typeArguments[0]);
            final valueType = _typeName(mapType.typeArguments[1]);
            settersCode +=
                '''static void set$paramName($keyType ${mapAnnotation.keyName}, $valueType newValue){
              FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
              try {
                finampSettingsTemp.${property.displayName}[${mapAnnotation.keyName}]=newValue;
              } on UnsupportedError{
                // We were using the default const map directly.  Clone to allow modifications.
                finampSettingsTemp.${property.displayName}=Map.from(finampSettingsTemp.${property.displayName});
                finampSettingsTemp.${property.displayName}[${mapAnnotation.keyName}]=newValue;
              }
              Hive.box<FinampSettings>("FinampSettings").put("FinampSettings", finampSettingsTemp);
            }
            ''';
          } else {
            if (typeArg.isDartCoreMap) {
              throw "Error on FinampSettings.${property.displayName} - Maps must have either a SettingsHelperMap or SettingsHelperIgnore annotation.";
            }
            settersCode += '''static void set$paramName(${_typeName(typeArg)} new$paramName){
              FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
              ''';
            // Make sure we use a new list instance so that getter fires.
            if (typeArg.isDartCoreList) {
              settersCode +=
                  '''if(finampSettingsTemp.${property.displayName}==new$paramName){
                new$paramName=new$paramName.toList();
              }
              ''';
            }
            settersCode += '''finampSettingsTemp.${property.displayName}=new$paramName;
              Hive.box<FinampSettings>("FinampSettings").put("FinampSettings", finampSettingsTemp);
              }
              ''';
          }
        }

        if (property.isGetter) {
          if (mapAnnotationObj != null) {
            if (!property.returnType.isDartCoreMap) {
              throw "Error on FinampSettings.${property.displayName} - Non-Maps cannot have SettingsHelperMap annotation.";
            }
            final mapAnnotation = SettingsHelperMap.fromRaw(mapAnnotationObj);
            final mapType = property.returnType as ParameterizedType;
            final keyType = _typeName(mapType.typeArguments[0]);
            final valueType = _typeName(mapType.typeArguments[1]);
            final returnType = valueType.endsWith("?") ? valueType : "$valueType?";
            selectorsCode +=
                '''ProviderListenable<$returnType> ${property.displayName}($keyType ${mapAnnotation.keyName}) => 
              finampSettingsProvider.select((value) => value.requireValue.${property.displayName}[${mapAnnotation.keyName}]);
              ''';
            if (mapAnnotation.keyGetter) {
              selectorsCode +=
                  '''ProviderListenable<Iterable<$keyType>> get ${property.displayName}Keys => 
              finampSettingsProvider.select((value) => _LengthEqualsIterable(value.requireValue.${property.displayName}.keys));
              ''';
            }
          } else {
            if (property.returnType.isDartCoreMap) {
              throw "Error on FinampSettings.${property.displayName} - Maps must have either a SettingsHelperMap or SettingsHelperIgnore annotation.";
            }
            selectorsCode +=
                '''ProviderListenable<${_typeName(property.returnType)}> get ${property.displayName} => 
              finampSettingsProvider.select((value) => value.requireValue.${property.displayName});
        ''';
          }
        }
      }
    }

    return '''
    // coverage:ignore-file
    // ignore_for_file: type=lint

    /// Generated setters for all finampSettings.  Must be directly accessed until
    /// static extension methods are added to dart
    extension FinampSetters on FinampSettingsHelper {
      $settersCode
    }
    
    /// Generated providers to easily watch only specific fields in finampSettings
    extension FinampSettingsProviderSelectors on StreamProvider<FinampSettings>{
      $selectorsCode
    }
    
    // Needs import of 'package:collection/collection.dart' in parent file
    class _LengthEqualsIterable<E> extends DelegatingIterable<E>{
      _LengthEqualsIterable(super.base);

      @override
      bool operator ==(Object other) {
        return other is _LengthEqualsIterable && other.length == length;
      }

      @override
      int get hashCode => Object.hash(length,'_LengthEqualsIterable');
    }
    ''';
  }

  static String _typeName(DartType type) {
    var typeArg = type.element!.displayName;
    if (type is ParameterizedType && type.typeArguments.isNotEmpty) {
      typeArg = "$typeArg<${type.typeArguments.map((x) => _typeName(x)).join(",")}>";
    }
    if (type.nullabilitySuffix == NullabilitySuffix.question) {
      typeArg = "$typeArg?";
    }
    return typeArg;
  }
}
