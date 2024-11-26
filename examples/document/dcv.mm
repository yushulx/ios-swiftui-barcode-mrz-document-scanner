#import "DCV-Bridging-Header.h"

#import <CoreVideo/CoreVideo.h>
#import <Foundation/Foundation.h>

#if defined(__APPLE__) && defined(__MACH__) && !TARGET_OS_IPHONE
#import <Cocoa/Cocoa.h>
@implementation CaptureVisionWrapper {
  CCaptureVisionRouter *cvr;
}

+ (int)initializeLicense:(NSString *)licenseKey {
  char errorMsgBuffer[512]; // Buffer for error messages

  // Convert NSString to C string
  const char *licenseCString = [licenseKey UTF8String];

  // Call the C++ class method
  int ret = CLicenseManager::InitLicense(licenseCString, errorMsgBuffer,
                                         sizeof(errorMsgBuffer));

  // Handle the return value
  if (ret != 0) {
    NSString *errorMessage = [NSString stringWithUTF8String:errorMsgBuffer];
    NSLog(@"License initialization failed: %@", errorMessage);
  } else {
    NSLog(@"License initialized successfully");
  }

  return ret;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    cvr = new CCaptureVisionRouter(); // Initialize the C++ object
  }

  char errorMsgBuffer[512];
  int ret = cvr->InitSettings(jsonString.c_str(), errorMsgBuffer,
                              sizeof(errorMsgBuffer));

  if (ret != 0) {
    NSString *errorMessage = [NSString stringWithUTF8String:errorMsgBuffer];
    NSLog(@"Init setting failed: %@", errorMessage);
  }
  return self;
}

- (NSArray *)captureImageWithData:(void *)baseAddress
                            width:(int)width
                           height:(int)height
                           stride:(int)stride
                      pixelFormat:(OSType)pixelFormat {

  if (baseAddress == NULL) {
    NSLog(@"Base address is NULL.");
    return nil;
  }

  ImagePixelFormat sdkPixelFormat = [self mapPixelFormat:pixelFormat];

  // Construct CImageData
  CImageData *imageStruct =
      new CImageData(stride * height, (unsigned char *)baseAddress, width,
                     height, stride, sdkPixelFormat);

  // Call C++ method
  CCapturedResult *result = cvr->Capture(imageStruct, "");

  if (result->GetErrorCode() != 0) {
    NSLog(@"Error code: %d", result->GetErrorCode());
  }
  CNormalizedImagesResult *documentResult = result->GetNormalizedImagesResult();
  if (documentResult == nullptr || documentResult->GetItemsCount() == 0) {
    NSLog(@"No document found");
    delete imageStruct;
    return nil;
  }

  int documentResultItemCount = documentResult->GetItemsCount();
  NSLog(@"Total document(s) found: %d", documentResultItemCount);
  NSMutableArray *documentArray = [NSMutableArray array];

  for (int j = 0; j < documentResultItemCount; j++) {
    const CNormalizedImageResultItem *documentResultItem =
        documentResult->GetItem(j);

    //    CImageManager *imageManager = new CImageManager();

    const CImageData *imageData = documentResultItem->GetImageData();
    //      imageManager->SaveToFile(imageData,
    //      "/Users/user/Desktop/image.jpg");
    //    delete imageManager;
    const unsigned char *bytes = imageData->GetBytes();
    unsigned long size = imageData->GetBytesLength();
    int niWidth = imageData->GetWidth();
    int niHeight = imageData->GetHeight();
    int niStride = imageData->GetStride();
    ImagePixelFormat format = imageData->GetImagePixelFormat();
    NSImage *image = [self convertToNSImageWithBytes:bytes
                                                size:size
                                               width:niWidth
                                              height:niHeight
                                              stride:niStride
                                              format:format];

    CPoint *points = documentResultItem->GetLocation().points;
    NSLog(@"Result %d", j + 1);

    NSDictionary *documentData = @{
      @"points" : @[
        @{@"x" : @(points[0][0]), @"y" : @(height - points[0][1])},
        @{@"x" : @(points[1][0]), @"y" : @(height - points[1][1])},
        @{@"x" : @(points[2][0]), @"y" : @(height - points[2][1])},
        @{@"x" : @(points[3][0]), @"y" : @(height - points[3][1])}
      ],
      @"image" : image
    };

    [documentArray addObject:documentData];
  }

  if (documentResult)
    documentResult->Release();

  result->Release();

  delete imageStruct;
  return [documentArray copy];
}

- (NSImage *)convertToNSImageWithBytes:(const unsigned char *)bytes
                                  size:(unsigned long)size
                                 width:(int)width
                                height:(int)height
                                stride:(int)stride
                                format:(ImagePixelFormat)format {
  // Determine pixel format
  NSBitmapFormat bitmapFormat = 0;
  int bitsPerPixel = 0;
  int samplesPerPixel = 0;

  switch (format) {
  case IPF_RGB_888:
    bitmapFormat = 0;    // No special format flags for RGB
    bitsPerPixel = 24;   // 8 bits for R, G, B
    samplesPerPixel = 3; // 3 color channels
    break;
  case IPF_ARGB_8888:
    bitmapFormat = NSBitmapFormatAlphaFirst;
    bitsPerPixel = 32;   // 8 bits for A, R, G, B
    samplesPerPixel = 4; // 4 channels (A, R, G, B)
    break;
  case IPF_GRAYSCALED:
    bitmapFormat = 0;    // No special format flags for grayscale
    bitsPerPixel = 8;    // 8 bits for grayscale
    samplesPerPixel = 1; // 1 channel (grayscale)
    break;
  default:
    NSLog(@"Unsupported pixel format");
    return nil;
  }

  // Create NSBitmapImageRep
  NSBitmapImageRep *imageRep = [[NSBitmapImageRep alloc]
      initWithBitmapDataPlanes:NULL
                    pixelsWide:width
                    pixelsHigh:height
                 bitsPerSample:8
               samplesPerPixel:samplesPerPixel
                      hasAlpha:(samplesPerPixel == 4)
                      isPlanar:NO
                colorSpaceName:NSCalibratedRGBColorSpace
                  bitmapFormat:bitmapFormat
                   bytesPerRow:stride
                  bitsPerPixel:bitsPerPixel];
  if (!imageRep) {
    NSLog(@"Failed to create NSBitmapImageRep.");
    return nil;
  }

  // Copy pixel data into the image rep
  memcpy([imageRep bitmapData], bytes, size);

  // Wrap in NSImage
  NSImage *image = [[NSImage alloc] initWithSize:NSMakeSize(width, height)];
  [image addRepresentation:imageRep];

  return image;
}

- (void)dealloc {
  // Clean up C++ object
  if (cvr) {
    delete cvr;
    cvr = nullptr;
  }
}

- (ImagePixelFormat)mapPixelFormat:(OSType)pixelFormat {
  switch (pixelFormat) {
  case kCVPixelFormatType_32BGRA:
    return IPF_ABGR_8888;
  default:
    return IPF_NV21;
  }
}

@end

#endif
