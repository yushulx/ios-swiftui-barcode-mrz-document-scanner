#ifndef DCV_H
#define DCV_H

#import <Foundation/Foundation.h>

//! Project version number for DCV.
FOUNDATION_EXPORT double DCVVersionNumber;

//! Project version string for DCV.
FOUNDATION_EXPORT const unsigned char DCVVersionString[];

typedef NS_ENUM(NSInteger, PixelFormat) {
    PixelFormatBinary = 0,
    PixelFormatBinaryInverted = 1,
    PixelFormatGrayscale = 2,
    PixelFormatNV21 = 3,
    PixelFormatRGB565 = 4,
    PixelFormatRGB555 = 5,
    PixelFormatRGB888 = 6,
    PixelFormatARGB8888 = 7,
    PixelFormatRGB161616 = 8,
    PixelFormatARGB16161616 = 9,
    PixelFormatABGR8888 = 10,
    PixelFormatABGR16161616 = 11,
    PixelFormatBGR888 = 12,
    PixelFormatBinary8 = 13,
    PixelFormatNV12 = 14,
    PixelFormatBinary8Inverted = 15
};

// Objective-C interface
@interface CaptureVisionWrapper : NSObject
+ (int)initializeLicense:(NSString *)licenseKey;

- (NSArray *)captureImageWithData:(void *)baseAddress
                            width:(int)width
                           height:(int)height
                           stride:(int)stride
                      pixelFormat:(PixelFormat)pixelFormat;

@end

#endif
