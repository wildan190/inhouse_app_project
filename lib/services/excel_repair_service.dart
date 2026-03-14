import 'dart:typed_data';
import 'dart:convert';
import 'package:archive/archive.dart';

class ExcelRepairService {
  /// Normalizes Excel structure to handle differences between WPS, MS Excel, and other exporters.
  List<int> normalizeExcel(List<int> bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final newArchive = Archive();

      for (final file in archive) {
        if (!file.isFile) continue;

        // SKIP NON-ESSENTIAL METADATA for better compatibility (WPS, LibreOffice, MS Excel)
        if (file.name.contains('calcChain.xml') || 
            file.name.contains('printerSettings') || 
            file.name.contains('customProperty') ||
            file.name.contains('drawings/') || 
            file.name.contains('media/') || 
            file.name.contains('theme/') || // Skip themes
            file.name.contains('metadata/') || // Skip metadata
            file.name.contains('customData/') || // Skip WPS custom data
            file.name.endsWith('.vml') ||
            file.name.contains('xl/styles.xml') || // ALWAYS remove styles to avoid corruption
            file.name.contains('_rels/drawing')) {
          continue;
        }

        dynamic content = file.content;
        
        // Strip references to removed objects in rels and sheet files using UTF-8 safe decoding
        if (file.name.endsWith('.rels') || (file.name.startsWith('xl/worksheets/sheet') && file.name.endsWith('.xml'))) {
          try {
            // Use UTF-8 for safe decoding of all characters (including non-ASCII from WPS)
            String xml = utf8.decode(content as List<int>, allowMalformed: true);
            
            // Aggressively remove <drawing ... />, <legacyDrawing ... />, and <s ... /> (style) tags
            xml = xml.replaceAll(RegExp(r'<drawing[^>]*/>'), '');
            xml = xml.replaceAll(RegExp(r'<drawing[^>]*>.*?</drawing>', dotAll: true), '');
            xml = xml.replaceAll(RegExp(r'<legacyDrawing[^>]*/>'), '');
            xml = xml.replaceAll(RegExp(r'<legacyDrawing[^>]*>.*?</legacyDrawing>', dotAll: true), '');
            
            // Remove style references from cells: s="123" -> nothing
            xml = xml.replaceAll(RegExp(r' s="[0-9]*"'), '');
            
            // Remove Relationship references to drawings/styles/themes/metadata
            xml = xml.replaceAll(RegExp(r'<Relationship[^>]*Target="[^"]*(drawing|styles|theme|metadata|calcChain|printerSettings)[^"]*"[^>]*/>'), '');
            
            // WPS specific: strip custom namespaces if causing issues
            xml = xml.replaceAll(RegExp(r' xmlns:wps="[^"]*"'), '');
            xml = xml.replaceAll(RegExp(r'<wps:[^>]*>.*?</wps:[^>]*>', dotAll: true), '');

            content = utf8.encode(xml);
          } catch (e) {
            print('UTF-8 decode failed for ${file.name}, using fallback char codes: $e');
            // Fallback for non-UTF8 XML (rare in .xlsx but possible in some exporters)
            String xml = String.fromCharCodes(content as List<int>);
            xml = xml.replaceAll(RegExp(r' s="[0-9]*"'), '');
            content = Uint8List.fromList(xml.codeUnits);
          }
        }

        newArchive.addFile(ArchiveFile(file.name, file.size, content));
      }

      return ZipEncoder().encode(newArchive) ?? bytes;
    } catch (e) {
      print('Normalization failed, using original bytes: $e');
      return bytes;
    }
  }

  /// Repairs corrupted Excel files by removing problematic metadata.
  /// If aggressive is true, it removes styles.xml and drawings to ensure raw data can be read.
  List<int>? repairExcel(List<int> bytes, {bool aggressive = false}) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final newArchive = Archive();
      bool modified = false;

      for (final file in archive) {
        if (!file.isFile) continue;

        // Aggressively remove styles and drawings to fix formatting/object errors
        if (aggressive && (file.name == 'xl/styles.xml' || file.name.contains('drawings/'))) {
          modified = true;
          continue;
        }

        dynamic content = file.content;
        
        // Also strip from sheets in aggressive mode
        if (aggressive && file.name.startsWith('xl/worksheets/sheet') && file.name.endsWith('.xml')) {
          String xml = String.fromCharCodes(content as List<int>);
          xml = xml.replaceAll(RegExp(r'<drawing[^>]*/>'), '');
          xml = xml.replaceAll(RegExp(r'<drawing[^>]*>.*?</drawing>', dotAll: true), '');
          xml = xml.replaceAll(RegExp(r'<legacyDrawing[^>]*/>'), '');
          xml = xml.replaceAll(RegExp(r'<legacyDrawing[^>]*>.*?</legacyDrawing>', dotAll: true), '');
          content = Uint8List.fromList(xml.codeUnits);
          modified = true;
        }

        newArchive.addFile(ArchiveFile(file.name, file.size, content));
      }

      return modified ? ZipEncoder().encode(newArchive) : null;
    } catch (e) {
      print('Repair failed: $e');
      return null;
    }
  }
}
