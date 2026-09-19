// ignore_for_file: avoid_print

import 'dart:io';
import 'package:image/image.dart';

void main() {
  var img = decodeImage(File("android/app/src/main/res/drawable-xxxhdpi/ic_launcher_foreground.png").readAsBytesSync());
  if (img != null) {
    print('Size: ${img.width}x${img.height}');
    print('Format: ${img.format}');
    print('Num channels: ${img.numChannels}');
    
    // Check edge pixels for transparency
    int transparentCount = 0;
    int totalEdgePixels = 0;
    
    for (int x = 0; x < img.width; x++) {
      var topPixel = img.getPixel(x, 0);
      var bottomPixel = img.getPixel(x, img.height - 1);
      if (topPixel.a == 0) transparentCount++;
      if (bottomPixel.a == 0) transparentCount++;
      totalEdgePixels += 2;
    }
    
    for (int y = 0; y < img.height; y++) {
      var leftPixel = img.getPixel(0, y);
      var rightPixel = img.getPixel(img.width - 1, y);
      if (leftPixel.a == 0) transparentCount++;
      if (rightPixel.a == 0) transparentCount++;
      totalEdgePixels += 2;
    }
    
    print('Edge transparent pixels: $transparentCount / $totalEdgePixels (${(transparentCount/totalEdgePixels*100).toStringAsFixed(1)}%)');
    
    // Check safe zone (17% from edge for 66% safe zone)
    // xxxhdpi is 432x432, 17% = ~73px
    int safeZoneMargin = (img.width * 0.17).round();
    var safeZonePixel = img.getPixel(safeZoneMargin, safeZoneMargin);
    print('Safe zone inner corner ($safeZoneMargin,$safeZoneMargin) alpha: ${safeZonePixel.a}');
    
    // Check content at center
    var centerPixel = img.getPixel(img.width ~/ 2, img.height ~/ 2);
    print('Center pixel: rgb(${centerPixel.r},${centerPixel.g},${centerPixel.b}) a=${centerPixel.a}');
  } else {
    print('Failed to decode image');
  }
}