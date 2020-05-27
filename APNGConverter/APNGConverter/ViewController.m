//
//  ViewController.m
//  APNGConverter
//
//  Created by Lide on 2020/5/20.
//  Copyright © 2020 Lide. All rights reserved.
//

#import "ViewController.h"
#import "XDXHardwareEncoder.h"
#import "YYImageCoder.h"
#import <AVFoundation/AVFoundation.h>
#import "FileParser.h"
#import "HardwareDecoder.h"

@interface ViewController () {
    NSButton    *_openButton;
    NSImageView *_imageView;
    NSButton    *_convertButton;
    XDXHardwareEncoder  *_encoder;
    NSButton    *_playButton;
    PlayView    *_playView;
    AVSampleBufferDisplayLayer  *_displayLayer;
    FileParser  *_fileParser;
    HardwareDecoder             *_decoder;
}

@property (nonatomic, strong) NSURL *fileURL;
@property (nonatomic, strong) NSMutableArray *fileURLArray;
@property (nonatomic, strong) NSImage *image;

@end

@implementation ViewController

@synthesize openButton = _openButton;
@synthesize imageView = _imageView;
@synthesize convertButton = _convertButton;
@synthesize playButton = _playButton;
@synthesize playView = _playView;

- (id)init {
    self = [super init];
    if (self != nil) {

    }

    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    _fileURLArray = [NSMutableArray arrayWithCapacity:0];

    // Do any additional setup after loading the view.
    _convertButton.hidden = YES;
    _encoder = [XDXHardwareEncoder getInstance];
    _encoder.enableH264 = YES;
    [_encoder prepareForEncode];

    _playButton.hidden = YES;

    _decoder = [[HardwareDecoder alloc] init];
}

- (IBAction)clickOpenButton:(id)sender {
    NSOpenPanel *openPanel = [[NSOpenPanel alloc] init];
    openPanel.showsResizeIndicator = YES;
    openPanel.showsHiddenFiles = NO;
    openPanel.allowsMultipleSelection = YES;
    openPanel.canChooseDirectories = NO;
    [openPanel setAllowedFileTypes:@[@"png"]];
    if ([openPanel runModal] == NSModalResponseOK) {
        NSURL *fileURL = openPanel.URL;
        if (fileURL != nil) {
            self.fileURL = fileURL;
            [self showImageView];
        }

        if ([openPanel.URLs count] > 1) {
            [_fileURLArray addObjectsFromArray:openPanel.URLs];
        }
    }
}

- (void)showImageView {
    _imageView.animates = YES;
    NSImage *image = [[NSImage alloc] initWithContentsOfURL:self.fileURL];
    self.image = image;
    _imageView.image = image;
    _convertButton.hidden = NO;
}

- (void)clickConvertButton:(id)sender {
    [_encoder startWithWidth:self.image.size.width * 2 andHeight:self.image.size.height andFPS:30];

    if ([self.fileURLArray count] > 0) {
        [self.fileURLArray enumerateObjectsUsingBlock:^(NSURL *fileURL, NSUInteger idx, BOOL * _Nonnull stop) {
            NSData *data = [[NSData alloc] initWithContentsOfURL:fileURL];
            YYImageDecoder *decoder = [YYImageDecoder decoderWithData:data scale:1.0];
            for (NSInteger i = 0; i < decoder.frameCount; i++) {
                @autoreleasepool {
                    YYImageFrame *frame = [decoder frameAtIndex:i decodeForDisplay:YES];

                    CVPixelBufferRef pixelBuffer = [self pixelBufferFromCGImage:frame.imageRef];
                    CMSampleTimingInfo info;
                    info.presentationTimeStamp = CMTimeMake(i, 15);
                    NSTimeInterval duration = [decoder frameDurationAtIndex:i];
                    info.duration = CMTimeMake(duration * 1000000000, 1000000000);
                    info.decodeTimeStamp = kCMTimeInvalid;

                    CMVideoFormatDescriptionRef formatDesc;
                    CMVideoFormatDescriptionCreateForImageBuffer(kCFAllocatorDefault, pixelBuffer, &formatDesc);

                    CMSampleBufferRef sampleBuffer;
                    CMSampleBufferCreateReadyWithImageBuffer(kCFAllocatorDefault,
                                                             pixelBuffer,
                                                             formatDesc,
                                                             &info,
                                                             &sampleBuffer);
                    [_encoder encode:sampleBuffer];

                    CVPixelBufferRelease(pixelBuffer);
                    CFRelease(formatDesc);
                    CFRelease(sampleBuffer);
                    CGImageRelease(frame.imageRef);
                }
            }
        }];
    } else {
        NSData *data = [[NSData alloc] initWithContentsOfURL:self.fileURL];
        YYImageDecoder *decoder = [YYImageDecoder decoderWithData:data scale:1.0];
        for (NSInteger i = 0; i < decoder.frameCount; i++) {
            YYImageFrame *frame = [decoder frameAtIndex:i decodeForDisplay:YES];

            CVPixelBufferRef pixelBuffer = [self pixelBufferFromCGImage:frame.imageRef];
            CMSampleTimingInfo info;
            info.presentationTimeStamp = CMTimeMake(i, 15);
            NSTimeInterval duration = [decoder frameDurationAtIndex:i];
            info.duration = CMTimeMake(duration * 1000000000, 1000000000);
            info.decodeTimeStamp = kCMTimeInvalid;

            CMVideoFormatDescriptionRef formatDesc;
            CMVideoFormatDescriptionCreateForImageBuffer(kCFAllocatorDefault, pixelBuffer, &formatDesc);

            CMSampleBufferRef sampleBuffer;
            CMSampleBufferCreateReadyWithImageBuffer(kCFAllocatorDefault,
                                                     pixelBuffer,
                                                     formatDesc,
                                                     &info,
                                                     &sampleBuffer);
            [_encoder encode:sampleBuffer];

            CVPixelBufferRelease(pixelBuffer);
            CFRelease(formatDesc);
            CFRelease(sampleBuffer);
        }
    }

    _playButton.hidden = NO;
}

- (CVPixelBufferRef) pixelBufferFromCGImage: (CGImageRef) image
{
    //83 177 114
    NSDictionary *options = @{
                              (NSString*)kCVPixelBufferCGImageCompatibilityKey : @YES,
                              (NSString*)kCVPixelBufferCGBitmapContextCompatibilityKey : @YES,
                              (NSString*)kCVPixelBufferIOSurfacePropertiesKey: [NSDictionary dictionary]
                              };
    CVPixelBufferRef pxbuffer = NULL;

    CGFloat frameWidth = CGImageGetWidth(image);
    CGFloat frameHeight = CGImageGetHeight(image);

    CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault,
                                          frameWidth * 2,
                                          frameHeight,
                                          kCVPixelFormatType_32ARGB,
                                          (__bridge CFDictionaryRef) options,
                                          &pxbuffer);

    NSParameterAssert(status == kCVReturnSuccess && pxbuffer != NULL);

    CVPixelBufferLockBaseAddress(pxbuffer, 0);
    void *pxdata = CVPixelBufferGetBaseAddress(pxbuffer);
    NSParameterAssert(pxdata != NULL);

    CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();

    CGContextRef context = CGBitmapContextCreate(pxdata,
                                                 frameWidth * 2,
                                                 frameHeight,
                                                 8,
                                                 CVPixelBufferGetBytesPerRow(pxbuffer),
                                                 rgbColorSpace,
                                                 (CGBitmapInfo)kCGImageAlphaNoneSkipFirst);
    NSParameterAssert(context);
    CGContextConcatCTM(context, CGAffineTransformIdentity);

//    CGContextSetFillColorWithColor(context, CGColorCreateSRGB(83.0 / 255.0, 177.0 / 255.0, 114.0 / 255.0, 1.0));
//    CGContextFillRect(context, CGRectMake(0,
//                                          0,
//                                          frameWidth * 2,
//                                          frameHeight));

    CFDataRef rawData = CGDataProviderCopyData(CGImageGetDataProvider(image));
    UInt8 * buf = (UInt8 *) CFDataGetBytePtr(rawData);
    CFIndex length = CFDataGetLength(rawData);
    UInt8 *alphaBuf = malloc(sizeof(UInt8) * length);
    for(unsigned long i = 0; i < length; i += 4) {
        alphaBuf[i] = buf[i + 3];
        alphaBuf[i + 1] = buf[i + 3];
        alphaBuf[i + 2] = buf[i + 3];
        alphaBuf[i + 3] = 0xFF;
    }
    CFRelease(rawData);

    size_t bufferLength = length;
    CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, alphaBuf, bufferLength, NULL);
    size_t bitsPerComponent = 8;
    size_t bitsPerPixel = 32;
    size_t bytesPerRow = 4 * frameWidth;

//    CGColorSpaceRef colorSpaceRef = CGColorSpaceCreateDeviceRGB();
//    if(colorSpaceRef == NULL) {
//        NSLog(@"Error allocating color space");
//        CGDataProviderRelease(provider);
//        return nil;
//    }

    CGBitmapInfo bitmapInfo = kCGBitmapByteOrderDefault;
    CGColorRenderingIntent renderingIntent = kCGRenderingIntentDefault;

    CGImageRef iref = CGImageCreate(frameWidth,
                                    frameHeight,
                                    bitsPerComponent,
                                    bitsPerPixel,
                                    bytesPerRow,
                                    rgbColorSpace,//colorSpaceRef,
                                    bitmapInfo,
                                    provider,   // data provider
                                    NULL,       // decode
                                    YES,            // should interpolate
                                    renderingIntent);

    CGContextDrawImage(context, CGRectMake(0,
                                           0,
                                           frameWidth,
                                           frameHeight),
                       image);
    CGContextDrawImage(context, CGRectMake(frameWidth,
                        0,
                        frameWidth,
                        frameHeight),
    iref);
    CGImageRelease(iref);
    free(alphaBuf);
    CGColorSpaceRelease(rgbColorSpace);
    CGContextRelease(context);

    CVPixelBufferUnlockBaseAddress(pxbuffer, 0);

    return pxbuffer;
}

- (IBAction)clickPlayButton:(id)sender {
    if (_displayLayer == nil) {
        _displayLayer = [[AVSampleBufferDisplayLayer alloc] init];
        _displayLayer.bounds = _playView.bounds;
        _displayLayer.position = CGPointMake(CGRectGetMidX(_playView.bounds), CGRectGetMidY(_playView.bounds));
        _displayLayer.videoGravity = AVLayerVideoGravityResizeAspect;
        CMTimebaseRef controlTimebase;
        CMTimebaseCreateWithMasterClock(CFAllocatorGetDefault(), CMClockGetHostTimeClock(), &controlTimebase);
        _displayLayer.controlTimebase = controlTimebase;
        CMTimebaseSetRate(_displayLayer.controlTimebase, 1.0);
        [_playView.layer addSublayer:_displayLayer];
    }

    [_decoder prepareForPlay];
    _fileParser = [[FileParser alloc] initWithURL:[NSURL URLWithString:_encoder.filePath]];
    [_fileParser startParserWithDataBlock:^(NSData * _Nonnull data) {
//        [_decoder decodeWithData:data andAVSLayer:_displayLayer];
        [_decoder decodeWithData:data result:^(CVPixelBufferRef  _Nonnull pixelBuffer) {
            @autoreleasepool {
                CIImage *ciImage = [CIImage imageWithCVPixelBuffer:pixelBuffer];
                CIContext *context = [CIContext contextWithOptions:nil];
                unsigned long width = CVPixelBufferGetWidth(pixelBuffer);
                unsigned long height = CVPixelBufferGetHeight(pixelBuffer);
                CGImageRef imageRef = [context createCGImage:ciImage fromRect:CGRectMake(0, 0, width, height)];
                NSImage *image = [[NSImage alloc] initWithCGImage:imageRef size:CGSizeMake(width, height)];
                dispatch_async(dispatch_get_main_queue(), ^{
                    _playView.image = image;
                });
                CGImageRelease(imageRef);
            }
        }];
    }];
}

- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];

    // Update the view, if already loaded.
}

@end
