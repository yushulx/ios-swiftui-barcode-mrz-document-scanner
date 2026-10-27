/*
 * This is the header files of DynamsoftBarcodeScanner.
 *
 * Copyright © Dynamsoft Corporation.  All rights reserved.
 */

#import <Foundation/Foundation.h>

FOUNDATION_EXPORT double DynamsoftBarcodeScannerVersionNumber;

FOUNDATION_EXPORT const unsigned char DynamsoftBarcodeScannerVersionString[];

// Since v11 the barcode reader, camera enhancer, license, image processing,
// capture vision router and utility modules all live in the single
// DynamsoftCaptureVisionBundle framework.
#import <DynamsoftCaptureVisionBundle/DynamsoftCaptureVisionBundle.h>
