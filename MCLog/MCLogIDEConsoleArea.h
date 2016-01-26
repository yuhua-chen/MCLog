//
//  MCLogIDEConsoleArea.h
//  MCLog
//
//  Created by Alex Lee on 1/6/16.
//  Copyright © 2016 Yuhua Chen. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface MCLogIDEConsoleArea : NSViewController

- (BOOL)_shouldAppendItem:(id)obj;
- (void)_clearText;

@end

