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
    
    // Clean URL: trim spaces and handle potentially encoded characters
    String cleanUrl = url.trim();
    if (!cleanUrl.startsWith('http')) {
      print('Invalid image URL: $cleanUrl');
      return null;
    }

    try {
      final response = await http.get(
        Uri.parse(cleanUrl),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
          'Accept': 'image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
        },
      );
      
      if (response.statusCode == 200) {
        final Uint8List bytes = response.bodyBytes;
        if (bytes.isEmpty) return null;
        
        final ui.ImmutableBuffer buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
        final ui.ImageDescriptor descriptor = await ui.ImageDescriptor.encoded(buffer);
        final ui.Codec codec = await descriptor.instantiateCodec();
        final ui.FrameInfo frameInfo = await codec.getNextFrame();
        buffer.dispose();
        return frameInfo.image;
      } else {
        print('Failed to fetch linked image. Status code: ${response.statusCode}, URL: $url');
      }
    } catch (e) {
      print('Error fetching linked image: $e, URL: $url');
    }
    return null;
  }
}
