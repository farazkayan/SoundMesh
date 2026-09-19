// ignore_for_file: avoid_print

import 'dart:io';
import 'package:image/image.dart';

void main() {
  var img = decodeImage(File("assets/images/FOR_APP_ICON.png").readAsBytesSync());
  if (img != null) {
    print('Size: ${img.width}x${img.height}');
    print('Format: ${img.format}');
    print('Num channels: ${img.numChannels}');
    
    // Check edge pixels for transparency
    int transparentCount = 0;
    int totalEdgePixels = 0;
    
    // Check top and bottom edges
    for (int x = 0; x < img.width; x++) {
      var topPixel = img.getPixel(x, 0);
      var bottomPixel = img.getPixel(x, img.height - 1);
      if (topPixel.a == 0) transparentCount++;
      if (bottomPixel.a == 0) transparentCount++;
      totalEdgePixels += 2;
    }
    
    // Check left and right edges
    for (int y = 0; y < img.height; y++) {
      var leftPixel = img.getPixel(0, y);
      var rightPixel = img.getPixel(img.width - 1, y);
      if (leftPixel.a == 0) transparentCount++;
      if (rightPixel.a == 0) transparentCount++;
      totalEdgePixels += 2;
    }
    
    print('Edge transparent pixels: $transparentCount / $totalEdgePixels (${(transparentCount/totalEdgePixels*100).toStringAsFixed(1)}%)');
    
    // Check corners
    var corners = [
      img.getPixel(0, 0),
      img.getPixel(img.width - 1, 0),
      img.getPixel(0, img.height - 1),
      img.getPixel(img.width - 1, img.height - 1),
    ];
    print('Corner alphas: ${corners.map((p) => p.a).join(', ')}');
    
    // Sample some pixels near edges (10% in)
    int margin = (img.width * 0.1).round();
    var samplePixels = [
      img.getPixel(margin, margin),
      img.getPixel(img.width - margin - 1, margin),
      img.getPixel(margin, img.height - margin - 1),
      img.getPixel(img.width - margin - 1, img.height - margin - 1),
    ];
    print('10% margin alphas: ${samplePixels.map((p) => p.a).join(', ')}');
    print('10% margin colors: ${samplePixels.map((p) => 'rgb(${p.r},${p.g},${p.b})').join(', ')}');
    
    // Check center
    var centerPixel = img.getPixel(img.width ~/ 2, img.height ~/ 2);
    print('Center pixel: rgb(${centerPixel.r},${centerPixel.g},${centerPixel.b}) a=${centerPixel.a}');
  } else {
    print('Failed to decode image');
  }
}