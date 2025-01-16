//
//  DCV.h
//  DCV
//
//  Created by Xiao Ling on 1/16/25.
//

#import <Foundation/Foundation.h>

//! Project version number for DCV.
FOUNDATION_EXPORT double DCVVersionNumber;

//! Project version string for DCV.
FOUNDATION_EXPORT const unsigned char DCVVersionString[];


// Objective-C interface
@interface CaptureVisionWrapper : NSObject
+ (int)initializeLicense:(NSString *)licenseKey;

- (NSArray *)captureImageWithData:(void *)baseAddress
                                 width:(int)width
                                height:(int)height
                                stride:(int)stride
                           pixelFormat:(OSType)pixelFormat;

@end


