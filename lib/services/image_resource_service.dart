import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class ImageResourceService {
  // Helper to load original image efficiently
  Future<ui.Image?> loadOriginalImage(File? uploadedImage) async {
    if (uploadedImage == null || !await uploadedImage.exists()) return null;
    try {
      final Uint8List imageBytes = await uploadedImage.readAsBytes();
      final ui.ImmutableBuffer buffer = await ui.ImmutableBuffer.fromUint8List(imageBytes);
      final ui.ImageDescriptor descriptor = await ui.ImageDescriptor.encoded(buffer);
      final ui.Codec codec = await descriptor.instantiateCodec();
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      buffer.dispose();
      return frameInfo.image;
    } catch (e) {
      print('Error loading original image: $e');
      return null;
    }
  }

  // Helper to load linked image in parallel
  Future<ui.Image?> loadLinkedImage(String url) async {
    if (url.isEmpty) return null;
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final ui.ImmutableBuffer buffer = await ui.ImmutableBuffer.fromUint8List(response.bodyBytes);
        final ui.ImageDescriptor descriptor = await ui.ImageDescriptor.encoded(buffer);
        final ui.Codec codec = await descriptor.instantiateCodec();
        final ui.FrameInfo frameInfo = await codec.getNextFrame();
        buffer.dispose();
        return frameInfo.image;
      }
    } catch (e) {
      print('Error fetching linked image: $e');
    }
    return null;
  }
}
