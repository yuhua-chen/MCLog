//
//  MCLog.h
//  MCLog
//
//  Created by Michael Chen on 2014/8/1.
//  Copyright (c) 2014年 Yuhua Chen. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MCLogIDEConsoleArea : NSViewController
- (BOOL)_shouldAppendItem:(id)obj;
@end

@interface MCLog : NSObject
+ (void)pluginDidLoad:(NSBundle *)bundle;
@end

void replaceShouldAppendItemMethod();
