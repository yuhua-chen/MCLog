//
//  MCLogIDEConsoleArea.m
//  MCLog
//
//  Created by Alex Lee on 1/6/16.
//  Copyright © 2016 Yuhua Chen. All rights reserved.
//

#import "MCLogIDEConsoleArea.h"
#import "Utils.h"
#import "NSSearchField+MCLog.h"
#import "MCOrderedMap.h"
#import "MCLog.h"
#import "MCIDEConsoleItem.h"
#import "MethodSwizzle.h"
#import <objc/runtime.h>




@implementation MCLogIDEConsoleArea

+ (void)load {
    Class clazz = NSClassFromString(@"IDEConsoleArea");
    IMP hookedShouldAppendItemIMP = class_getMethodImplementation([MCLogIDEConsoleArea class],
                                                                  @selector(_shouldAppendItem:));
    
    [MethodSwizzleHelper swizzleMethodForClass:clazz
                                      selector:@selector(_shouldAppendItem:)
                                replacementIMP:hookedShouldAppendItemIMP
                                 isClassMethod:NO];
    
    IMP hookClearTextIMP = class_getMethodImplementation([MCLogIDEConsoleArea class], @selector(_clearText));
    [MethodSwizzleHelper swizzleMethodForClass:clazz
                                      selector:@selector(_clearText)
                                replacementIMP:hookClearTextIMP
                                 isClassMethod:NO];
}

- (BOOL)_shouldAppendItem:(id)obj;
{
    static IMP originalIMP = nil;
    if (originalIMP == nil) {
        Class clazz = NSClassFromString(@"IDEConsoleArea");
        SEL selector = @selector(_shouldAppendItem:);
        originalIMP = [MethodSwizzleHelper originalIMPForClass:clazz selector:selector];
    }
    
    
    NSSearchField *searchField = getSearchField(self);
    if (searchField == nil) {
        return YES;
    }
    if (!searchField.consoleArea) {
        searchField.consoleArea = self;
    }
    
    NSMutableDictionary *consoleItemsMap = [MCLog consoleItemsMap];
    NSString *consoleItemsKey = hash(self);
    
    MCOrderedMap *originConsoleItems = consoleItemsMap[consoleItemsKey];
    if (!originConsoleItems) {
        originConsoleItems = [[MCOrderedMap alloc] init];
        originConsoleItems.maximumnItemsCount = 65535;
        consoleItemsMap[consoleItemsKey] = originConsoleItems;
    }
    [originConsoleItems addObject:obj forKey:@([obj timestamp])];

    BOOL isInputItem           = [[obj valueForKey:@"input"] boolValue];
    BOOL isPromptItem          = [[obj valueForKey:@"prompt"] boolValue];
    BOOL isoutputRequestByUser = [[obj valueForKey:@"outputRequestedByUser"] boolValue];
    BOOL isDebuggerAdaptor     = [[obj valueForKey:@"adaptorType"] hasSuffix:@".Debugger"];

    NSInteger filterMode = [[self valueForKey:@"filterMode"] intValue];
    BOOL shouldShowLogLevel = YES;
    if (filterMode >= MCLogLevelVerbose) {
        shouldShowLogLevel =
            [obj logLevel] >= filterMode || isInputItem || isPromptItem || isoutputRequestByUser || isDebuggerAdaptor;
    } else {
        shouldShowLogLevel = [originalIMP(self, _cmd, obj) boolValue];
    }
    
    if (!shouldShowLogLevel) {
        return NO;
    }

    if (searchField.stringValue.length == 0) {
        return YES;
    }
    
    // Remove prefix log pattern
    NSString *content = [obj content];
    NSRange range = NSMakeRange(0, content.length);
    
    NSRegularExpression *logRegex = logItemPrefixPattern();
    content = [logRegex stringByReplacingMatchesInString:content options:(NSRegularExpressionCaseInsensitive | NSRegularExpressionDotMatchesLineSeparators) range:range withTemplate:@""];

    // Test with user's regex pattern
    NSRegularExpression *regex = [MCLog filterPatternsMap][consoleItemsKey];
    NSError *error;
    if (regex == nil || ![regex.pattern isEqualToString:searchField.stringValue]) {
        regex = [NSRegularExpression regularExpressionWithPattern:searchField.stringValue
                                                          options:(NSRegularExpressionCaseInsensitive |
                                                                   NSRegularExpressionDotMatchesLineSeparators)
                                                            error:&error];
        if (regex == nil) {
            // display all if with regex is error
            MCLogger(@"error:%@", error);
            return YES;
        }
        [MCLog filterPatternsMap][consoleItemsKey] = regex;
    }

    range = NSMakeRange(0, content.length);
    NSArray *matches = [regex matchesInString:content options:0 range:range];
    if ([matches count] > 0 || isInputItem || isPromptItem || isoutputRequestByUser || isDebuggerAdaptor) {
        return YES;
    }
    
    return NO;
}

- (void)_clearText
{
    static IMP originalIMP = nil;
    if (originalIMP == nil) {
        Class clazz = NSClassFromString(@"IDEConsoleArea");
        SEL selector = @selector(_clearText);
        originalIMP = [MethodSwizzleHelper originalIMPForClass:clazz selector:selector];
    }
    
    originalIMP(self, _cmd);
    [[MCLog consoleItemsMap] removeObjectForKey:hash(self)];
}
@end
