//
//  HardwareDecoder.m
//  APNGConverter
//
//  Created by Lide on 2020/5/21.
//  Copyright © 2020 Lide. All rights reserved.
//

#import "HardwareDecoder.h"

@interface HardwareDecoder () {
    dispatch_queue_t    _decodeQueue;

    VTDecompressionSessionRef _deocderSession;
    CMVideoFormatDescriptionRef _decoderFormatDescription;

    NSData  *_spsData;
    NSData  *_ppsData;

    NSTimeInterval  _startTime;
    NSInteger       _count;
}

@end

@implementation HardwareDecoder

- (id)init {
    self = [super init];
    if (self != nil) {
        _decodeQueue = dispatch_queue_create("com.lide.decode.queue", DISPATCH_QUEUE_SERIAL);
    }

    return self;
}

- (void)prepareForPlay {
    _startTime = 0;
    _count = 0;
}

- (void)decodeWithData:(NSData *)data andAVSLayer:(AVSampleBufferDisplayLayer *)avslayer {
    dispatch_async(_decodeQueue, ^{
        if (!data || data.length < 5) {
            return;
        }

        BOOL needDecode = NO;
        uint8_t *bytes = (uint8_t *)[data bytes];
        int nalType = bytes[4] & 0x1F;
        switch (nalType) {
            case 0x01: {
                // need size
                uint32_t length = (uint32_t)[data length] - 4;
                uint8_t *b = malloc(sizeof(uint8_t) * 4);
                b[0] = (length >> 24) & 0xFF;
                b[1] = (length >> 16) & 0xFF;
                b[2] = (length >> 8) & 0xFF;
                b[3] = length & 0xFF;
                memcpy(bytes, b, 4);
                free(b);
                needDecode = YES;
            }
                break;
            case 0x05: {
                // need size
                uint32_t length = (uint32_t)[data length] - 4;
                uint8_t *b = malloc(sizeof(uint8_t) * 4);
                b[0] = (length >> 24) & 0xFF;
                b[1] = (length >> 16) & 0xFF;
                b[2] = (length >> 8) & 0xFF;
                b[3] = length & 0xFF;
                memcpy(bytes, b, 4);
                free(b);
                needDecode = YES;
            }
                break;
            case 0x07:
                _spsData = [data subdataWithRange:NSMakeRange(4, data.length - 4)];
                break;
            case 0x08:
                _ppsData = [data subdataWithRange:NSMakeRange(4, data.length - 4)];
                break;
            default:
                return;
                break;
        }

        [self setupDecoder];

        if (!needDecode) {
            return;
        }

        CMSampleBufferRef sampleBuffer = NULL;
        sampleBuffer = [self decodeToSampleBufferRef:data];
        if (sampleBuffer) {
            if (avslayer != nil && [avslayer isReadyForMoreMediaData]) {
                if (_startTime == 0.0) {
                    _startTime = [[NSDate date] timeIntervalSince1970];
                }
                [avslayer enqueueSampleBuffer:sampleBuffer];
                _count++;
                NSTimeInterval currentTime = [[NSDate date] timeIntervalSince1970];
                NSTimeInterval sleepTime = _startTime + 1.0 / 20.0 * _count - currentTime;
                if (sleepTime > 0) {
                    usleep(sleepTime * 1000000);
                    NSLog(@"sleep time is: %i", (int)(sleepTime * 1000000));
                }
            }
            CFRelease(sampleBuffer);
        }
    });
}

- (void)decodeWithData:(NSData *)data result:(void (^)(CVPixelBufferRef pixelBuffer))resultBlock {
    dispatch_async(_decodeQueue, ^{
        if (!data || data.length < 5) {
            return;
        }

        BOOL needDecode = NO;
        uint8_t *bytes = (uint8_t *)[data bytes];
        int nalType = bytes[4] & 0x1F;
        switch (nalType) {
            case 0x01: {
                // need size
                uint32_t length = (uint32_t)[data length] - 4;
                uint8_t *b = malloc(sizeof(uint8_t) * 4);
                b[0] = (length >> 24) & 0xFF;
                b[1] = (length >> 16) & 0xFF;
                b[2] = (length >> 8) & 0xFF;
                b[3] = length & 0xFF;
                memcpy(bytes, b, 4);
                free(b);
                needDecode = YES;
            }
                break;
            case 0x05: {
                // need size
                uint32_t length = (uint32_t)[data length] - 4;
                uint8_t *b = malloc(sizeof(uint8_t) * 4);
                b[0] = (length >> 24) & 0xFF;
                b[1] = (length >> 16) & 0xFF;
                b[2] = (length >> 8) & 0xFF;
                b[3] = length & 0xFF;
                memcpy(bytes, b, 4);
                free(b);
                needDecode = YES;
            }
                break;
            case 0x07:
                _spsData = [data subdataWithRange:NSMakeRange(4, data.length - 4)];
                break;
            case 0x08:
                _ppsData = [data subdataWithRange:NSMakeRange(4, data.length - 4)];
                break;
            default:
                return;
                break;
        }

        [self setupDecoder];

        if (!needDecode) {
            return;
        }

        CVPixelBufferRef pixelBuffer = NULL;
        pixelBuffer = [self decodeNALU:data];
        NSLog(@"decode video data length: %lu", (unsigned long)data.length);
        if (pixelBuffer != NULL) {
            if (_startTime == 0.0) {
                _startTime = [[NSDate date] timeIntervalSince1970];
            }
            if (resultBlock) {
                resultBlock(pixelBuffer);
            }
            _count++;
            NSTimeInterval currentTime = [[NSDate date] timeIntervalSince1970];
            NSTimeInterval sleepTime = _startTime + 1.0 / 20.0 * _count - currentTime;
            if (sleepTime > 0) {
                usleep(sleepTime * 1000000);
                NSLog(@"sleep time is: %i", (int)(sleepTime * 1000000));
            }
        }
        CVPixelBufferRelease(pixelBuffer);
    });
}

- (CVPixelBufferRef)decodeNALU:(NSData *)data {
    if (!_deocderSession) {
        return nil;
    }

    CVPixelBufferRef outputPixelBuffer = NULL;

    CMBlockBufferRef blockBuffer = NULL;
    OSStatus status  = CMBlockBufferCreateWithMemoryBlock(kCFAllocatorDefault,
                                                          (void*)data.bytes, data.length,
                                                          kCFAllocatorNull,
                                                          NULL, 0, data.length,
                                                          0, &blockBuffer);
    if(status == kCMBlockBufferNoErr) {
        CMSampleBufferRef sampleBuffer = NULL;
        const size_t sampleSizeArray[] = {data.length};
        status = CMSampleBufferCreateReady(kCFAllocatorDefault,
                                           blockBuffer,
                                           _decoderFormatDescription ,
                                           1, 0, NULL, 1, sampleSizeArray,
                                           &sampleBuffer);
        if (status == kCMBlockBufferNoErr && sampleBuffer) {
            VTDecodeFrameFlags flags = 0;
            VTDecodeInfoFlags flagOut = 0;
            OSStatus decodeStatus = VTDecompressionSessionDecodeFrame(_deocderSession,
                                                                      sampleBuffer,
                                                                      flags,
                                                                      &outputPixelBuffer,
                                                                      &flagOut);

            if(decodeStatus == kVTInvalidSessionErr) {
                NSLog(@"IOS8VT: Invalid session, reset decoder session");
            } else if(decodeStatus == kVTVideoDecoderBadDataErr) {
                NSLog(@"IOS8VT: decode failed status=%d(Bad data)", decodeStatus);
            } else if(decodeStatus != noErr) {
                NSLog(@"IOS8VT: decode failed status=%d", decodeStatus);
            }

            CFRelease(sampleBuffer);
        }
        CFRelease(blockBuffer);
    }

    CVPixelBufferRef transBuffer = [self transformPixelBuffer:outputPixelBuffer];
    return transBuffer;
//    return outputPixelBuffer;
}

- (CVPixelBufferRef)transformPixelBuffer:(CVPixelBufferRef)pixelBuffer {
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);

//    size_t count = CVPixelBufferGetPlaneCount(pixelBuffer);
//    size_t yWidth = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0);
//    size_t yHeight = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0);
//    size_t uvWidth = CVPixelBufferGetWidthOfPlane(pixelBuffer, 1);
//    size_t uvHeight = CVPixelBufferGetHeightOfPlane(pixelBuffer, 1);
//    uint8_t *yAddr = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
//    uint8_t *uAddr = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1);
//    uint8_t *vAddr = uAddr + uvWidth * uvHeight / 2;
//    uint8_t y = yAddr[0];
//    uint8_t u = uAddr[0];
//    uint8_t v = uAddr[1];
//    uint8_t r = (298 * (y - 16) + 409 * (v - 128) + 128) >> 8;
//    uint8_t g = (298 * (y - 16) - 100 * (u - 128) - 208 * (v - 128) + 128) >> 8;
//    uint8_t b = (298 * (y - 16) + 516 * (u - 128) + 128) >> 8;

    NSDictionary *options = @{
    (NSString*)kCVPixelBufferCGImageCompatibilityKey : @YES,
    (NSString*)kCVPixelBufferCGBitmapContextCompatibilityKey : @YES,
    (NSString*)kCVPixelBufferIOSurfacePropertiesKey: [NSDictionary dictionary]
    };
    CVPixelBufferRef pxbuffer = NULL;

    unsigned long frameWidth = CVPixelBufferGetWidth(pixelBuffer) / 2;
    unsigned long frameHeight = CVPixelBufferGetHeight(pixelBuffer);

    CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault,
                                          frameWidth,
                                          frameHeight,
                                          kCVPixelFormatType_32BGRA,
                                          (__bridge CFDictionaryRef) options,
                                          &pxbuffer);

    NSParameterAssert(status == kCVReturnSuccess && pxbuffer != NULL);

    CVPixelBufferLockBaseAddress(pxbuffer, 0);
    void *pxdata = CVPixelBufferGetBaseAddress(pxbuffer);
    NSParameterAssert(pxdata != NULL);

    CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();

    CGContextRef context = CGBitmapContextCreate(pxdata,
                                                 frameWidth,
                                                 frameHeight,
                                                 8,
                                                 CVPixelBufferGetBytesPerRow(pxbuffer),
                                                 rgbColorSpace,
                                                 (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
    NSParameterAssert(context);
    CGContextConcatCTM(context, CGAffineTransformIdentity);

    CFIndex length = frameWidth * frameHeight * 4;
    UInt8 *alphaBuf = malloc(sizeof(UInt8) * length);

    // start
//    size_t count = CVPixelBufferGetPlaneCount(pixelBuffer);
    unsigned long yWidth = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0);
//    size_t yHeight = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0);
    size_t uvWidth = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1);
//    size_t uvHeight = CVPixelBufferGetHeightOfPlane(pixelBuffer, 1);
    uint8_t *yAddr = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
    uint16_t *uvAddr = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1);

    for (int i = 0; i < frameHeight; i++) {
        for (int j = 0; j < frameWidth; j++) {
            unsigned long index = (i * frameWidth + j) * 4;
            unsigned long yIndex = i * yWidth + j;
            unsigned long uIndex = j / 2 + (i / 2) * yWidth / 2;
            unsigned long yaIndex = i * yWidth + j + frameWidth;
            unsigned long uaIndex = j / 2 + (i / 2) * yWidth / 2 + uvWidth / 4;

            double y = (double)yAddr[yIndex];
            double v = (uint16_t)uvAddr[uIndex] >> 8;
            double u = (uint16_t)uvAddr[uIndex] & 0xFF;

            y = (y - 16.0) / 220.0 * 255.0;
            v = (v - 16.0) / 225.0 * 255.0;
            u = (u - 16.0) / 225.0 * 255.0;

            double ya = yAddr[yaIndex];
            double va = (uint16_t)uvAddr[uaIndex] >> 8;
            double ua = (uint16_t)uvAddr[uaIndex] & 0xFF;

            ya = (ya - 16.0) / 220.0 * 255.0;
            va = (va - 16.0) / 225.0 * 255.0;

//            double r = y + 1.28033 * (v - 128);
//            double g = y - 0.21482 * (u - 128) - 0.38059 * (v - 128);
//            double b = y + 2.12798 * (u - 128);

            double r = y + (1.370705 * (v - 128));
            double g = y - (0.337633 * (u - 128)) - (0.698001 * (v - 128));
            double b = y + (1.732446 * (u - 128));

            double ra = ya + (1.370705 * (va - 128));
            double ga = ya - (0.337633 * (ua - 128)) - (0.698001 * (va - 128));
            double ba = ya + (1.732446 * (ua - 128));

//            r -= ra;
//            g -= ga;
//            b -= ba;

            if (r < 0) {
                r = 0;
            }
            if (r > 255) {
                r = 255;
            }
            if (g < 0) {
                g = 0;
            }
            if (g > 255) {
                g = 255;
            }
            if (b < 0) {
                b = 0;
            }
            if (b > 255) {
                b = 255;
            }

            if (ra < 0) {
                ra = 0;
            }
            if (ra > 255) {
                ra = 255;
            }
            if (ga < 0) {
                ga = 0;
            }
            if (ga > 255) {
                ga = 255;
            }
            if (ba < 0) {
                ba = 0;
            }
            if (ba > 255) {
                ba = 255;
            }

            alphaBuf[index] = b;
            alphaBuf[index + 1] = g;
            alphaBuf[index + 2] = r;
            alphaBuf[index + 3] = ra;
        }
    }

    size_t bufferLength = length;
    CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, alphaBuf, bufferLength, NULL);
    size_t bitsPerComponent = 8;
    size_t bitsPerPixel = 32;
    size_t bytesPerRow = 4 * frameWidth;

    CGColorSpaceRef colorSpaceRef = CGColorSpaceCreateDeviceRGB();
    if(colorSpaceRef == NULL) {
        NSLog(@"Error allocating color space");
        CGDataProviderRelease(provider);
        return nil;
    }

    CGBitmapInfo bitmapInfo = (CGBitmapInfo)kCGImageAlphaLast;
    CGColorRenderingIntent renderingIntent = kCGRenderingIntentDefault;

    CGImageRef iref = CGImageCreate(frameWidth,
                                    frameHeight,
                                    bitsPerComponent,
                                    bitsPerPixel,
                                    bytesPerRow,
                                    colorSpaceRef,
                                    bitmapInfo,
                                    provider,   // data provider
                                    NULL,       // decode
                                    YES,            // should interpolate
                                    renderingIntent);
    CGContextSetFillColorWithColor(context, CGColorCreateSRGB(1.0, 0.0, 0.0, 0.0));
    CGContextFillRect(context, CGRectMake(0,
                                          0,
                                          frameWidth,
                                          frameHeight));
    CGContextDrawImage(context, CGRectMake(0,
                                           0,
                                           frameWidth,
                                           frameHeight),
                       iref);

    CGImageRelease(iref);
    free(alphaBuf);
    CGColorSpaceRelease(rgbColorSpace);
    CGContextRelease(context);

    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);

    return pxbuffer;
}

- (BOOL)setupDecoder {
    if(_deocderSession) {
        return YES;
    }

    const uint8_t* const parameterSetPointers[2] = { _spsData.bytes, _ppsData.bytes };
    const size_t parameterSetSizes[2] = { _spsData.length, _ppsData.length };
    OSStatus status = CMVideoFormatDescriptionCreateFromH264ParameterSets(kCFAllocatorDefault,
                                                                          2, //param count
                                                                          parameterSetPointers,
                                                                          parameterSetSizes,
                                                                          4, //nal start code size
                                                                          &_decoderFormatDescription);

    if(status == noErr) {
//        CFDictionaryRef attrs = NULL;
//        const void *keys[] = { kCVPixelBufferPixelFormatTypeKey };
        uint32_t v = kCVPixelFormatType_420YpCbCr8BiPlanarFullRange;
//        const void *values[] = { CFNumberCreate(NULL, kCFNumberSInt32Type, &v) };
//        attrs = CFDictionaryCreate(NULL, keys, values, 1, NULL, NULL);

        VTDecompressionOutputCallbackRecord callBackRecord;
        callBackRecord.decompressionOutputCallback = didDecompress;
        callBackRecord.decompressionOutputRefCon = NULL;

        status = VTDecompressionSessionCreate(kCFAllocatorDefault,
                                              _decoderFormatDescription,
                                              NULL, NULL,//attrs,
                                              &callBackRecord,
                                              &_deocderSession);
//        CFRelease(attrs);
    } else {
        NSLog(@"IOS8VT: reset decoder session failed status=%d", status);
    }

    return YES;
}

static void didDecompress( void *decompressionOutputRefCon, void *sourceFrameRefCon, OSStatus status, VTDecodeInfoFlags infoFlags, CVImageBufferRef pixelBuffer, CMTime presentationTimeStamp, CMTime presentationDuration ){

    CVPixelBufferRef *outputPixelBuffer = (CVPixelBufferRef *)sourceFrameRefCon;
    *outputPixelBuffer = CVPixelBufferRetain(pixelBuffer);
}

- (CMSampleBufferRef)decodeToSampleBufferRef:(NSData *)videoData {
    CMBlockBufferRef blockBuffer = NULL;
    CMSampleBufferRef sampleBuffer = NULL;

    OSStatus status = CMBlockBufferCreateWithMemoryBlock(kCFAllocatorDefault,
                                                         (void*)videoData.bytes, videoData.length,
                                                         kCFAllocatorNull,
                                                         NULL, 0, videoData.length,
                                                         0, &blockBuffer);
    if (status == kCMBlockBufferNoErr) {
        const size_t sampleSizeArray[] = {videoData.length};

        status = CMSampleBufferCreateReady(kCFAllocatorDefault,
                                           blockBuffer,
                                           _decoderFormatDescription,
                                           1, 0, NULL, 1, sampleSizeArray,
                                           &sampleBuffer);
        CFRelease(blockBuffer);
        CFArrayRef attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, YES);
        CFMutableDictionaryRef dict = (CFMutableDictionaryRef)CFArrayGetValueAtIndex(attachments, 0);
        CFDictionarySetValue(dict, kCMSampleAttachmentKey_DisplayImmediately, kCFBooleanTrue);

        return sampleBuffer;
    } else {
        return NULL;
    }
}

@end
