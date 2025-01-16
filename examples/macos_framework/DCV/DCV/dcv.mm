#import <CoreVideo/CoreVideo.h>
#import <Foundation/Foundation.h>

#import "DCV.h"

#ifdef __cplusplus
#include "DynamsoftCaptureVisionRouter.h"
#include "DynamsoftUtility.h"
#include "template.h"

// Use namespaces conditionally to avoid polluting global namespace
using namespace dynamsoft::license;
using namespace dynamsoft::cvr;
using namespace dynamsoft::dbr;
using namespace dynamsoft::utility;
using namespace dynamsoft::basic_structures;

#endif /* __cplusplus */ // End C++ block

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
                      pixelFormat:(PixelFormat)pixelFormat {
  

  // Construct CImageData
  CImageData *imageStruct =
      new CImageData(stride * height, (unsigned char *)baseAddress, width,
                     height, stride, static_cast<ImagePixelFormat>(pixelFormat));

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
        @{@"x" : @(points[0][0]), @"y" : @(height - points[0][1])},
        @{@"x" : @(points[1][0]), @"y" : @(height - points[1][1])},
        @{@"x" : @(points[2][0]), @"y" : @(height - points[2][1])},
        @{@"x" : @(points[3][0]), @"y" : @(height - points[3][1])}
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

@end

