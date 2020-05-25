//
//  HardwareDecoder.h
//  APNGConverter
//
//  Created by Lide on 2020/5/21.
//  Copyright © 2020 Lide. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <VideoToolbox/VideoToolbox.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface HardwareDecoder : NSObject

- (void)prepareForPlay;
- (void)decodeWithData:(NSData *)data andAVSLayer:(AVSampleBufferDisplayLayer *)avslayer;
- (void)decodeWithData:(NSData *)data result:(void (^)(CVPixelBufferRef pixelBuffer))resultBlock;

@end

NS_ASSUME_NONNULL_END
