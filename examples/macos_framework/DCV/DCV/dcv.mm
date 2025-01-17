#import <CoreVideo/CoreVideo.h>
#import <Foundation/Foundation.h>

#import "DCV.h"

#ifdef __cplusplus
#include "DynamsoftCaptureVisionRouter.h"
#include "DynamsoftUtility.h"
#include "template.h"

// Use namespaces conditionally to avoid polluting the global namespace
using namespace dynamsoft::license;
using namespace dynamsoft::cvr;
using namespace dynamsoft::dbr;
using namespace dynamsoft::utility;
using namespace dynamsoft::basic_structures;

#endif /* __cplusplus */ // End C++ block

@implementation CaptureVisionWrapper {
  CCaptureVisionRouter *cvr; // C++ object for capture vision router
}

#pragma mark - License Initialization

+ (int)initializeLicense:(NSString *)licenseKey {
  char errorMsgBuffer[512] = {0}; // Buffer for error messages

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

#pragma mark - Initialization

- (instancetype)init {
  self = [super init];
  if (self) {
    try {
      cvr = new CCaptureVisionRouter(); // Initialize the C++ object

      char errorMsgBuffer[512] = {0};
      int ret = cvr->InitSettings(jsonString.c_str(), errorMsgBuffer,
                                  sizeof(errorMsgBuffer));

      if (ret != 0) {
        NSString *errorMessage = [NSString stringWithUTF8String:errorMsgBuffer];
        NSLog(@"Init setting failed: %@", errorMessage);
      }
    } catch (const std::exception &ex) {
      NSLog(@"Exception during initialization: %s", ex.what());
    } catch (...) {
      NSLog(@"Unknown exception during initialization");
    }
  }
  return self;
}

#pragma mark - Image Capture Methods

- (NSArray *)decodeBufferWithData:(void *)baseAddress
                            width:(int)width
                           height:(int)height
                           stride:(int)stride
                      pixelFormat:(PixelFormat)pixelFormat {
  if (!baseAddress) {
    NSLog(@"Error: baseAddress is null");
    return nil;
  }

  NSArray *results = nil;

  try {
    // Construct CImageData
    CImageData *imageStruct = new CImageData(
        stride * height, (unsigned char *)baseAddress, width, height, stride,
        static_cast<ImagePixelFormat>(pixelFormat));

    // Call C++ method
    CCapturedResult *result = cvr->Capture(imageStruct, "");
    results = [self wrapResults:result];

    // Clean up
    delete imageStruct;
  } catch (const std::exception &ex) {
    NSLog(@"Exception during captureImageWithData: %s", ex.what());
  } catch (...) {
    NSLog(@"Unknown exception during captureImageWithData");
  }

  return results;
}

- (NSArray *)decodeFileWithPath:(NSString *)filePath {
  if (!filePath) {
    NSLog(@"Error: filePath is null");
    return nil;
  }

  NSArray *results = nil;

  try {
    // Convert NSString to C string
    const char *fileCString = [filePath UTF8String];
    CCapturedResult *result = cvr->Capture(fileCString, "");
    results = [self wrapResults:result];
  } catch (const std::exception &ex) {
    NSLog(@"Exception during captureImageWithFilePath: %s", ex.what());
  } catch (...) {
    NSLog(@"Unknown exception during captureImageWithFilePath");
  }

  return results;
}

#pragma mark - Result Wrapping

- (NSArray *)wrapResults:(CCapturedResult *)result {
  if (!result) {
    NSLog(@"Error: result is null");
    return nil;
  }

  NSMutableArray *barcodeArray = [NSMutableArray array];

  try {
    CDecodedBarcodesResult *barcodeResult = result->GetDecodedBarcodesResult();
    if (!barcodeResult || barcodeResult->GetItemsCount() == 0) {
      NSLog(@"No barcode found");
      return nil;
    }

    int barcodeResultItemCount = barcodeResult->GetItemsCount();
    NSLog(@"Total barcode(s) found: %d", barcodeResultItemCount);

    for (int j = 0; j < barcodeResultItemCount; j++) {
      const CBarcodeResultItem *barcodeResultItem = barcodeResult->GetItem(j);
      const char *format = barcodeResultItem->GetFormatString();
      const char *text = barcodeResultItem->GetText();
      int angle = barcodeResultItem->GetAngle();
      CPoint *points = barcodeResultItem->GetLocation().points;
      unsigned char *raw = barcodeResultItem->GetBytes();

      NSDictionary *barcodeData = @{
        @"format" : format ? [NSString stringWithUTF8String:format] : @"",
        @"text" : text ? [NSString stringWithUTF8String:text] : @"",
        @"angle" : @(angle),
        @"barcodeBytes" :
            [NSData dataWithBytes:raw
                           length:barcodeResultItem->GetBytesLength()],
        @"points" : @[
          @{@"x" : @(points[0][0]), @"y" : @(points[0][1])},
          @{@"x" : @(points[1][0]), @"y" : @(points[1][1])},
          @{@"x" : @(points[2][0]), @"y" : @(points[2][1])},
          @{@"x" : @(points[3][0]), @"y" : @(points[3][1])}
        ]
      };

      [barcodeArray addObject:barcodeData];
    }

    barcodeResult->Release();
    result->Release();
  } catch (const std::exception &ex) {
    NSLog(@"Exception during wrapResults: %s", ex.what());
  } catch (...) {
    NSLog(@"Unknown exception during wrapResults");
  }

  return [barcodeArray copy];
}

#pragma mark - Deallocation

- (void)dealloc {
  // Clean up C++ object
  if (cvr) {
    delete cvr;
    cvr = nullptr;
  }
}

#pragma mark - Get settings
- (NSString *)getSettings {
  char *tpl = cvr->OutputSettings("");
  NSString *settings = [NSString stringWithUTF8String:tpl];
  dynamsoft::cvr::CCaptureVisionRouter::FreeString(tpl);
  return settings;
}

#pragma mark - Set settings
- (int)setSettings:(NSString *)json {
  char *tpl = (char *)[json UTF8String];
  char errorMessage[256];
  int ret = cvr->InitSettings(tpl, errorMessage, 256);
  if (ret != 0) {
    NSLog(@"Set settings failed: %s", errorMessage);
  }
  return ret;
}

#pragma mark - Set barcode formats
- (int)setBarcodeFormats:(unsigned long long)formats {
  SimplifiedCaptureVisionSettings pSettings = {};
  cvr->GetSimplifiedSettings("", &pSettings);
  pSettings.barcodeSettings.barcodeFormatIds = formats;

  char szErrorMsgBuffer[256];
  int ret = cvr->UpdateSettings("", &pSettings, szErrorMsgBuffer, 256);
  if (ret != 0) {
    NSLog(@"Set barcode formats failed: %s", szErrorMsgBuffer);
  }
  return ret;
}
@end
