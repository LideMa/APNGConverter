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

    return outputPixelBuffer;
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
//        uint32_t v = kCVPixelFormatType_420YpCbCr8BiPlanarFullRange;
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
