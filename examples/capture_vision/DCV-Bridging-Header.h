#ifndef DCV_Bridging_Header_h
#define DCV_Bridging_Header_h

#include <TargetConditionals.h>

#if defined(__APPLE__) && defined(__MACH__) && !TARGET_OS_IPHONE
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

#import <Foundation/Foundation.h>

// Objective-C interface
@interface CaptureVisionWrapper : NSObject
+ (int)initializeLicense:(NSString *)licenseKey;

- (NSArray *)captureImageWithData:(void *)baseAddress
                                 width:(int)width
                                height:(int)height
                                stride:(int)stride
                           pixelFormat:(OSType)pixelFormat;

@end
#endif

#endif /* DCV_Bridging_Header_h */
