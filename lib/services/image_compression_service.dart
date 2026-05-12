import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as path;

class ImageCompressionService {
  static const int maxFileSizeBytes = 2 * 1024 * 1024; // 2MB
  static const int maxDimension = 800; // Max width/height
  static const int quality = 85; // JPEG quality (0-100)

  static Future<File?> compressImage(File imageFile) async {
    try {
      // Check file size first
      final fileSize = await imageFile.length();
      print('Original image size: ${fileSize} bytes');
      
      // If file is already small enough, return as-is
      if (fileSize <= maxFileSizeBytes) {
        print('Image is already within size limit');
        return imageFile;
      }

      // Read the image file
      final Uint8List imageBytes = await imageFile.readAsBytes();
      img.Image? originalImage = img.decodeImage(imageBytes);
      
      if (originalImage == null) {
        print('Failed to decode image');
        return null;
      }

      print('Original image dimensions: ${originalImage.width}x${originalImage.height}');

      // Calculate new dimensions while maintaining aspect ratio
      int newWidth = originalImage.width;
      int newHeight = originalImage.height;

      if (originalImage.width > maxDimension || originalImage.height > maxDimension) {
        if (originalImage.width > originalImage.height) {
          newWidth = maxDimension;
          newHeight = (originalImage.height * maxDimension / originalImage.width).round();
        } else {
          newHeight = maxDimension;
          newWidth = (originalImage.width * maxDimension / originalImage.height).round();
        }
      }

      // Resize the image
      img.Image resizedImage = img.copyResize(
        originalImage,
        width: newWidth,
        height: newHeight,
        interpolation: img.Interpolation.average,
      );

      print('Resized image dimensions: ${resizedImage.width}x${resizedImage.height}');

      // Convert to JPEG with compression
      Uint8List compressedBytes = Uint8List.fromList(img.encodeJpg(resizedImage, quality: quality));
      
      print('Compressed image size: ${compressedBytes.length} bytes');

      // Create a new compressed file
      final String compressedPath = _getCompressedFilePath(imageFile.path);
      File compressedFile = File(compressedPath);
      await compressedFile.writeAsBytes(compressedBytes);

      // If compression didn't help much, try even more aggressive compression
      if (compressedBytes.length > maxFileSizeBytes) {
        print('First compression insufficient, trying more aggressive compression');
        await _applyAggressiveCompression(compressedFile, resizedImage);
      }

      final finalSize = await compressedFile.length();
      print('Final compressed image size: ${finalSize} bytes');

      return compressedFile;
    } catch (e) {
      print('Error compressing image: $e');
      return null;
    }
  }

  static Future<void> _applyAggressiveCompression(File file, img.Image image) async {
    try {
      // Try progressively lower quality settings
      for (int qualityLevel in [70, 50, 30]) {
        final Uint8List compressedBytes = Uint8List.fromList(img.encodeJpg(image, quality: qualityLevel));
        
        print('Trying quality $qualityLevel: ${compressedBytes.length} bytes');
        
        if (compressedBytes.length <= maxFileSizeBytes) {
          await file.writeAsBytes(compressedBytes);
          print('Successfully compressed with quality $qualityLevel');
          return;
        }
      }
      
      // If still too large, resize further
      img.Image furtherResized = img.copyResize(
        image,
        width: (image.width * 0.8).round(),
        height: (image.height * 0.8).round(),
        interpolation: img.Interpolation.average,
      );
      
      final Uint8List compressedBytes = Uint8List.fromList(img.encodeJpg(furtherResized, quality: 30));
      await file.writeAsBytes(compressedBytes);
      print('Applied further resizing and low quality compression');
    } catch (e) {
      print('Error in aggressive compression: $e');
    }
  }

  static String _getCompressedFilePath(String originalPath) {
    final String directory = path.dirname(originalPath);
    final String fileNameWithoutExtension = path.basenameWithoutExtension(originalPath);
    final String extension = path.extension(originalPath);
    return path.join(directory, '${fileNameWithoutExtension}_compressed$extension');
  }

  static Future<bool> isImageSizeValid(File imageFile) async {
    try {
      final fileSize = await imageFile.length();
      return fileSize <= maxFileSizeBytes;
    } catch (e) {
      print('Error checking image size: $e');
      return false;
    }
  }

  static String getFormattedFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
