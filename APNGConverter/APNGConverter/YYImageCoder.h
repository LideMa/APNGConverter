//
//  YYImageCoder.h
//  YYImage <https://github.com/ibireme/YYImage>
//
//  Created by ibireme on 15/5/13.
//  Copyright (c) 2015 ibireme.
//
//  This source code is licensed under the MIT-style license found in the
//  LICENSE file in the root directory of this source tree.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, YYImageType) {
    YYImageTypeUnknown = 0, ///< unknown
    YYImageTypeJPEG,        ///< jpeg, jpg
    YYImageTypeJPEG2000,    ///< jp2
    YYImageTypeTIFF,        ///< tiff, tif
    YYImageTypeBMP,         ///< bmp
    YYImageTypeICO,         ///< ico
    YYImageTypeICNS,        ///< icns
    YYImageTypeGIF,         ///< gif
    YYImageTypePNG,         ///< png
    YYImageTypeWebP,        ///< webp
    YYImageTypeOther,       ///< other image format
};

/**
 Dispose method specifies how the area used by the current frame is to be treated
 before rendering the next frame on the canvas.
 */
typedef NS_ENUM(NSUInteger, YYImageDisposeMethod) {

    /**
     No disposal is done on this frame before rendering the next; the contents
     of the canvas are left as is.
     */
    YYImageDisposeNone = 0,

    /**
     The frame's region of the canvas is to be cleared to fully transparent black
     before rendering the next frame.
     */
    YYImageDisposeBackground,

    /**
     The frame's region of the canvas is to be reverted to the previous contents
     before rendering the next frame.
     */
    YYImageDisposePrevious,
};

/**
 Blend operation specifies how transparent pixels of the current frame are
 blended with those of the previous canvas.
 */
typedef NS_ENUM(NSUInteger, YYImageBlendOperation) {

    /**
     All color components of the frame, including alpha, overwrite the current
     contents of the frame's canvas region.
     */
    YYImageBlendNone = 0,

    /**
     The frame should be composited onto the output buffer based on its alpha.
     */
    YYImageBlendOver,
};


/**
 An image frame object.
 */
@interface YYImageFrame : NSObject <NSCopying>
@property (nonatomic) NSUInteger index;    ///< Frame index (zero based)
@property (nonatomic) NSUInteger width;    ///< Frame width
@property (nonatomic) NSUInteger height;   ///< Frame height
@property (nonatomic) NSUInteger offsetX;  ///< Frame origin.x in canvas (left-bottom based)
@property (nonatomic) NSUInteger offsetY;  ///< Frame origin.y in canvas (left-bottom based)
@property (nonatomic) NSTimeInterval duration;          ///< Frame duration in seconds
@property (nonatomic) YYImageDisposeMethod dispose;     ///< Frame dispose method.
@property (nonatomic) YYImageBlendOperation blend;      ///< Frame blend operation.
//@property (nullable, nonatomic, strong) UIImage *image; ///< The image.
@property (nonatomic) CGImageRef imageRef;
//+ (instancetype)frameWithImage:(UIImage *)image;
@end

#pragma mark - Decoder

/**
 An image decoder to decode image data.
 
 @discussion This class supports decoding animated WebP, APNG, GIF and system
 image format such as PNG, JPG, JP2, BMP, TIFF, PIC, ICNS and ICO. It can be used 
 to decode complete image data, or to decode incremental image data during image 
 download. This class is thread-safe.
 
 Example:
 
    // Decode single image:
    NSData *data = [NSData dataWithContentOfFile:@"/tmp/image.webp"];
    YYImageDecoder *decoder = [YYImageDecoder decoderWithData:data scale:2.0];
    UIImage image = [decoder frameAtIndex:0 decodeForDisplay:YES].image;
 
    // Decode image during download:
    NSMutableData *data = [NSMutableData new];
    YYImageDecoder *decoder = [[YYImageDecoder alloc] initWithScale:2.0];
    while(newDataArrived) {
        [data appendData:newData];
        [decoder updateData:data final:NO];
        if (decoder.frameCount > 0) {
            UIImage image = [decoder frameAtIndex:0 decodeForDisplay:YES].image;
            // progressive display...
        }
    }
    [decoder updateData:data final:YES];
    UIImage image = [decoder frameAtIndex:0 decodeForDisplay:YES].image;
    // final display...
 
 */
@interface YYImageDecoder : NSObject

@property (nullable, nonatomic, readonly) NSData *data;    ///< Image data.
@property (nonatomic, readonly) YYImageType type;          ///< Image data type.
@property (nonatomic, readonly) CGFloat scale;             ///< Image scale.
@property (nonatomic, readonly) NSUInteger frameCount;     ///< Image frame count.
@property (nonatomic, readonly) NSUInteger loopCount;      ///< Image loop count, 0 means infinite.
@property (nonatomic, readonly) NSUInteger width;          ///< Image canvas width.
@property (nonatomic, readonly) NSUInteger height;         ///< Image canvas height.
@property (nonatomic, readonly, getter=isFinalized) BOOL finalized;

/**
 Creates an image decoder.
 
 @param scale  Image's scale.
 @return An image decoder.
 */
- (instancetype)initWithScale:(CGFloat)scale NS_DESIGNATED_INITIALIZER;

/**
 Updates the incremental image with new data.
 
 @discussion You can use this method to decode progressive/interlaced/baseline
 image when you do not have the complete image data. The `data` was retained by
 decoder, you should not modify the data in other thread during decoding.
 
 @param data  The data to add to the image decoder. Each time you call this 
 function, the 'data' parameter must contain all of the image file data 
 accumulated so far.
 
 @param final  A value that specifies whether the data is the final set. 
 Pass YES if it is, NO otherwise. When the data is already finalized, you can
 not update the data anymore.
 
 @return Whether succeed.
 */
- (BOOL)updateData:(nullable NSData *)data final:(BOOL)final;

/**
 Convenience method to create a decoder with specified data.
 @param data  Image data.
 @param scale Image's scale.
 @return A new decoder, or nil if an error occurs.
 */
+ (nullable instancetype)decoderWithData:(NSData *)data scale:(CGFloat)scale;

/**
 Decodes and returns a frame from a specified index.
 @param index  Frame image index (zero-based).
 @param decodeForDisplay Whether decode the image to memory bitmap for display.
    If NO, it will try to returns the original frame data without blend.
 @return A new frame with image, or nil if an error occurs.
 */
- (nullable YYImageFrame *)frameAtIndex:(NSUInteger)index decodeForDisplay:(BOOL)decodeForDisplay;

/**
 Returns the frame duration from a specified index.
 @param index  Frame image (zero-based).
 @return Duration in seconds.
 */
- (NSTimeInterval)frameDurationAtIndex:(NSUInteger)index;

/**
 Returns the frame's properties. See "CGImageProperties.h" in ImageIO.framework
 for more information.
 
 @param index  Frame image index (zero-based).
 @return The ImageIO frame property.
 */
- (nullable NSDictionary *)framePropertiesAtIndex:(NSUInteger)index;

/**
 Returns the image's properties. See "CGImageProperties.h" in ImageIO.framework
 for more information.
 */
- (nullable NSDictionary *)imageProperties;

@end
