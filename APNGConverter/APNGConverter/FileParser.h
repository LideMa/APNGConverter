//
//  FileParser.h
//  APNGConverter
//
//  Created by Lide on 2020/5/22.
//  Copyright © 2020 Lide. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FileParser : NSObject

- (id)initWithURL:(NSURL *)fileURL;
- (void)startParserWithDataBlock:(void (^)(NSData *data))dataBlock;

@end

NS_ASSUME_NONNULL_END
