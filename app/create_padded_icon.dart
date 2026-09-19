import 'dart:io';
import 'package:image/image.dart';

void main() {
  // Load the original image
  var original = decodeImage(File("assets/images/FOR_APP_ICON.png").readAsBytesSync());
  if (original == null) {
    print("Failed to decode source image");
    return;
  }
  
  print("Original size: ${original.width}x${original.height}");
  
  // Convert to RGBA if needed
  var rgba = original.convert(numChannels: 4);
  
  // Create new canvas with same size but with transparency
  int canvasSize = 2000;
  var canvas = Image(width: canvasSize, height: canvasSize, numChannels: 4);
  
  // Safe zone is 66% of canvas (Android guideline)
  // So content should be 66% of 2000 = 1320 pixels
  // Padding on each side = (2000 - 1320) / 2 = 340 pixels
  double safeZoneRatio = 0.66;
  int contentSize = (canvasSize * safeZoneRatio).round();
  int padding = (canvasSize - contentSize) ~/ 2;
  
  print("Canvas: $canvasSize x $canvasSize");
  print("Content size: $contentSize x $contentSize");
  print("Padding: $padding px on each side");
  
  // Resize original to fit content size
  var resized = copyResize(rgba, width: contentSize, height: contentSize);
  
  // Draw resized image onto canvas at padding offset
  for (int y = 0; y < contentSize; y++) {
    for (int x = 0; x < contentSize; x++) {
      var pixel = resized.getPixel(x, y);
      canvas.setPixel(x + padding, y + padding, pixel);
    }
  }
  
  // Save the new padded image
  var outputPath = "assets/images/FOR_APP_ICON_PADDED.png";
  File(outputPath).writeAsBytesSync(encodePng(canvas));
  print("Saved padded image to $outputPath");
  
  // Verify the result
  var verify = decodeImage(File(outputPath).readAsBytesSync());
  if (verify != null) {
    int transparentCount = 0;
    int totalEdgePixels = 0;
    
    for (int x = 0; x < verify.width; x++) {
      var topPixel = verify.getPixel(x, 0);
      var bottomPixel = verify.getPixel(x, verify.height - 1);
      if (topPixel.a == 0) transparentCount++;
      if (bottomPixel.a == 0) transparentCount++;
      totalEdgePixels += 2;
    }
    
    for (int y = 0; y < verify.height; y++) {
      var leftPixel = verify.getPixel(0, y);
      var rightPixel = verify.getPixel(verify.width - 1, y);
      if (leftPixel.a == 0) transparentCount++;
      if (rightPixel.a == 0) transparentCount++;
      totalEdgePixels += 2;
    }
    
    print("Verified - Edge transparent pixels: $transparentCount / $totalEdgePixels (${(transparentCount/totalEdgePixels*100).toStringAsFixed(1)}%)");
    
    // Check safe zone boundary
    var safeZonePixel = verify.getPixel(padding, padding);
    print("Safe zone inner corner alpha: ${safeZonePixel.a}");
  }
}