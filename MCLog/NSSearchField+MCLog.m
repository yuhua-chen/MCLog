//
//  NSSearchField+MCLog.m
//  MCLog
//
//  Created by Alex Lee on 1/6/16.
//  Copyright © 2016 Yuhua Chen. All rights reserved.
//

#import "NSSearchField+MCLog.h"
#import "ALAssociatedWeakObject.h"
#import "MCLogIDEConsoleArea.h"
#import <objc/runtime.h>

static const void *kMCLogConsoleTextViewKey;
static const void *kMCLogIDEConsoleAreaKey;

@implementation NSSearchField (MCLog)

- (void)setConsoleArea:(MCLogIDEConsoleArea *)consoleArea {
    objc_setAssociatedObject(self, &kMCLogIDEConsoleAreaKey, consoleArea, OBJC_ASSOCIATION_ASSIGN);
    __weak typeof(self) weakSelf = self;
    [consoleArea mc_runAtDealloc:^{
        typeof(weakSelf) self = weakSelf;
        objc_setAssociatedObject(self, &kMCLogIDEConsoleAreaKey, nil, OBJC_ASSOCIATION_ASSIGN);
    }];
}

- (MCLogIDEConsoleArea *)consoleArea {
    return objc_getAssociatedObject(self, &kMCLogIDEConsoleAreaKey);
}

- (void)setConsoleTextView:(NSTextView *)consoleTextView {
    objc_setAssociatedObject(self, &kMCLogConsoleTextViewKey, consoleTextView, OBJC_ASSOCIATION_ASSIGN);
    __weak typeof(self) weakSelf = self;
    [consoleTextView mc_runAtDealloc:^{
        typeof(weakSelf) self = weakSelf;
        objc_setAssociatedObject(self, &kMCLogConsoleTextViewKey, nil, OBJC_ASSOCIATION_ASSIGN);
    }];
}

- (NSTextView *)consoleTextView {
    return objc_getAssociatedObject(self, &kMCLogConsoleTextViewKey);
}

@end
