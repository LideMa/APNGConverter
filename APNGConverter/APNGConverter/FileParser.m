//
//  FileParser.m
//  APNGConverter
//
//  Created by Lide on 2020/5/22.
//  Copyright © 2020 Lide. All rights reserved.
//

#import "FileParser.h"

@interface FileParser () {
    NSData          *_totalData;
    NSUInteger      _currentIndex;
    NSUInteger      _lastIndex;
}

@end

@implementation FileParser

- (id)initWithURL:(NSURL *)fileURL {
    self = [super init];
    if (self != nil) {
        _totalData = [NSData dataWithContentsOfFile:fileURL.absoluteString options:NSDataReadingUncached error:nil];
        _currentIndex = 0;
        _lastIndex = 0;
    }

    return self;
}

- (void)startParserWithDataBlock:(void (^)(NSData *data))dataBlock {
    const char *bytes = [_totalData bytes];
    for (long long i = 0; i < [_totalData length] - 3;) {
        if (*bytes == 0x00) {
            if (*(bytes + 1) == 0x00 && *(bytes + 2) == 0x00 && *(bytes + 3) == 0x01) {
                _currentIndex = i;
                if (_currentIndex != _lastIndex) {
                    NSData *subData = [_totalData subdataWithRange:NSMakeRange(_lastIndex, _currentIndex - _lastIndex)];
                    //
//                    NSLog(@"sub data is: %@", subData.description);
                    if (dataBlock != nil) {
                        dataBlock(subData);
                    }

                    _lastIndex = _currentIndex;
                    i += 4;
                    bytes = bytes + 4;

                    continue;
                }
            }
        }
        i++;
        bytes = bytes + 1;

        if (i >= [_totalData length] - 3) {
            // last piece
            NSData *lastData = [_totalData subdataWithRange:NSMakeRange(_lastIndex, _totalData.length - _lastIndex)];
            //
//            NSLog(@"last data is: %@", lastData.description);
            if (dataBlock != nil) {
                dataBlock(lastData);
            }

            break;
        }
    }
}

@end
