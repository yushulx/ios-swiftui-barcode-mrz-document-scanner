#import <CoreVideo/CoreVideo.h>
#import <Foundation/Foundation.h>

#import "DCV-Bridging-Header.h"

#if defined(__APPLE__) && defined(__MACH__) && !TARGET_OS_IPHONE

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

- (NSArray *)captureImageWithData:(NSData *)imageData
                            width:(int)width
                           height:(int)height
                           stride:(int)stride
                      pixelFormat:(OSType)pixelFormat {
  ImagePixelFormat sdkPixelFormat = [self mapPixelFormat:pixelFormat];

  // Construct CImageData
  CImageData *imageStruct =
      new CImageData(stride * height, (unsigned char *)[imageData bytes], width,
                     height, stride, sdkPixelFormat);

  // Call C++ method
  CCapturedResult *result = cvr->Capture(imageStruct, "");

  if (result->GetErrorCode() != 0) {
    NSLog(@"Error code: %d", result->GetErrorCode());
  }
  CDecodedBarcodesResult *barcodeResult = result->GetDecodedBarcodesResult();
  if (barcodeResult == nullptr || barcodeResult->GetItemsCount() == 0) {
    NSLog(@"No barcode found");
    delete imageStruct;
    return nil;
  }

  int barcodeResultItemCount = barcodeResult->GetItemsCount();
  NSLog(@"Total barcode(s) found: %d", barcodeResultItemCount);
  NSMutableArray *barcodeArray = [NSMutableArray array];

  for (int j = 0; j < barcodeResultItemCount; j++) {
    const CBarcodeResultItem *barcodeResultItem = barcodeResult->GetItem(j);
    const char *format = barcodeResultItem->GetFormatString();
    const char *text = barcodeResultItem->GetText();
    CPoint *points = barcodeResultItem->GetLocation().points;
    NSLog(@"Result %d", j + 1);
    NSLog(@"Barcode Format: %s", barcodeResultItem->GetFormatString());
    NSLog(@"Barcode Text: %s", barcodeResultItem->GetText());

    NSDictionary *barcodeData = @{
      @"format" : [NSString stringWithUTF8String:format],
      @"text" : [NSString stringWithUTF8String:text],
      @"points" : @[
        @{@"x" : @(points[0][0]), @"y" : @(points[0][1])},
        @{@"x" : @(points[1][0]), @"y" : @(points[1][1])},
        @{@"x" : @(points[2][0]), @"y" : @(points[2][1])},
        @{@"x" : @(points[3][0]), @"y" : @(points[3][1])}
      ]
    };

    [barcodeArray addObject:barcodeData];
  }

  if (barcodeResult)
    barcodeResult->Release();

  result->Release();

  delete imageStruct;
  return [barcodeArray copy];
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
  case kCVPixelFormatType_32ARGB:
    return IPF_ARGB_8888;
  case kCVPixelFormatType_32BGRA:
    return IPF_ABGR_8888;
  default:
    return IPF_NV21;
  }
}

@end

#endif
