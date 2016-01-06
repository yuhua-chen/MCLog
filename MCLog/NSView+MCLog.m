//
//  NSView+MCLog.m
//  MCLog
//
//  Created by Alex Lee on 1/6/16.
//  Copyright © 2016 Yuhua Chen. All rights reserved.
//

#import "NSView+MCLog.h"

NS_ASSUME_NONNULL_BEGIN

@implementation NSView (MCLog)

- (nullable __kindof NSView *)descendantViewByClassName:(NSString *)className{
    Class class = NSClassFromString(className);
    
    for (NSView *subView in self.subviews) {
        if ([subView isKindOfClass:class]) {
            return subView;
        } else {
            NSView *view = [subView descendantViewByClassName:className];
            if ([view isKindOfClass:class]) {
                return view;
            }
        }
    }
    return nil;
}

- (nullable __kindof NSView *)ancestralViewByClassName:(NSString *)className {
    if ([stringify(className) length] == 0) return nil;
    NSView *superView = self.superview;
    while (superView) {
        if ([[superView className] isEqualToString:className]) {
            return superView;
        }
        superView = superView.superview;
    }
    return nil;
}
@end

NS_ASSUME_NONNULL_END
