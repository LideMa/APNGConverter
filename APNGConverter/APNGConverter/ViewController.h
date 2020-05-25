//
//  ViewController.h
//  APNGConverter
//
//  Created by Lide on 2020/5/20.
//  Copyright © 2020 Lide. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "PlayView.h"

@interface ViewController : NSViewController

@property (nonatomic, strong) IBOutlet NSButton *openButton;
@property (nonatomic, strong) IBOutlet NSImageView *imageView;
@property (nonatomic, strong) IBOutlet NSButton *convertButton;
@property (nonatomic, strong) IBOutlet NSButton *playButton;
@property (nonatomic, strong) IBOutlet PlayView *playView;

- (IBAction)clickOpenButton:(id)sender;
- (IBAction)clickConvertButton:(id)sender;
- (IBAction)clickPlayButton:(id)sender;

@end

