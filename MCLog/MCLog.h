//
//  MCLog.h
//  MCLog
//
//  Created by Michael Chen on 2014/8/1.
//  Copyright (c) 2014年 Yuhua Chen. All rights reserved.
//

#import <Foundation/Foundation.h>

@class MCLogIDEConsoleArea;

@interface NSSearchField (MCLog)
@property (nonatomic, strong) MCLogIDEConsoleArea *consoleArea;
@property (nonatomic, strong) NSTextView *consoleTextView;
@end

@interface MCLogIDEConsoleArea : NSViewController
- (BOOL)_shouldAppendItem:(id)obj;
@end

@interface MCLog : NSObject
+ (void)pluginDidLoad:(NSBundle *)bundle;
@end

void replaceShouldAppendItemMethod();
NSSearchField *getSearchField(id consoleArea);
NSString *hash(id obj);