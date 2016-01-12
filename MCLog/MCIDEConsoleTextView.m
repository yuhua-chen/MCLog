//
//  MCIDEConsoleTextView.m
//  MCLog
//
//  Created by Alex Lee on 1/8/16.
//  Copyright © 2016 Yuhua Chen. All rights reserved.
//

#import "MCIDEConsoleTextView.h"
#import <objc/runtime.h>
#import "Utils.h"

void swizzleIDEConsoleTextView() {
    Class DVTTextStorage  = NSClassFromString(@"IDEConsoleTextView");
    Method originalMethod = class_getInstanceMethod(DVTTextStorage, @selector(writeSelectionToPasteboard:type:));
    Method swizzledMethod = class_getInstanceMethod(DVTTextStorage, @selector(mc_writeSelectionToPasteboard:type:));
    
    BOOL didAddMethod = class_addMethod(DVTTextStorage, @selector(writeSelectionToPasteboard:type:),
                                        method_getImplementation(swizzledMethod),
                                        method_getTypeEncoding(swizzledMethod));
    if (didAddMethod) {
        class_replaceMethod(DVTTextStorage, @selector(mc_writeSelectionToPasteboard:type:),
                            method_getImplementation(originalMethod),
                            method_getTypeEncoding(swizzledMethod));
    } else {
        method_exchangeImplementations(originalMethod, swizzledMethod);
    }
}

@implementation NSTextView (MCIDEConsoleTextView)

+ (void)load {
    swizzleIDEConsoleTextView();
}

// rewrite this method to avoid copy ANSI escape codes to pasteboard 
- (BOOL)mc_writeSelectionToPasteboard:(NSPasteboard *)pboard type:(NSString *)type {

    if ([self mc_writeSelectionToPasteboard:pboard type:type]) {
        NSString *text   = [pboard stringForType:type];
        NSArray *matches = [escCharPattern() matchesInString:text options:0 range:NSMakeRange(0, text.length)];
        for (NSInteger idx = matches.count - 1; idx >= 0; --idx) {
            NSTextCheckingResult *result = matches[idx];
            text = [text stringByReplacingCharactersInRange:result.range withString:@""];
        }
        return [pboard setString:text forType:type];
    }
    return NO;
}

@end
