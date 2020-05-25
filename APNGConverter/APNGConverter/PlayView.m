//
//  PlayView.m
//  APNGConverter
//
//  Created by Lide on 2020/5/22.
//  Copyright © 2020 Lide. All rights reserved.
//

#import "PlayView.h"

@implementation PlayView

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    
    // Drawing code here.
    [[NSColor whiteColor] setFill];
    NSRectFill(dirtyRect);
}

@end
