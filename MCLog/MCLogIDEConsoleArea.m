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


@implementation MCLogIDEConsoleArea

- (BOOL)_shouldAppendItem:(id)obj;
{
    static IMP originalIMP = nil;
    if (originalIMP == nil) {
        Class clazz = NSClassFromString(@"IDEConsoleArea");
        SEL selector = @selector(_shouldAppendItem:);
        originalIMP = [MethodSwizzleHelper originalIMPForClass:clazz selector:selector];
    }
    
    
    NSSearchField *searchField = getSearchField(self);
    if (!searchField.consoleArea) {
        searchField.consoleArea = self;
    }
    
    NSMutableDictionary *consoleItemsMap = [MCLog consoleItemsMap];
    NSString *consoleItemsKey = hash(self);
    
    MCOrderedMap *originConsoleItems = consoleItemsMap[consoleItemsKey];
    if (!originConsoleItems) {
        originConsoleItems = [[MCOrderedMap alloc] init];
        originConsoleItems.maximumnItemsCount = 65535;
    }

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
        if (searchField) {
            // store all console items.
            if (![originConsoleItems containsObjectForKey:@([obj timestamp])]) {
                [originConsoleItems addObject:obj forKey:@([obj timestamp])];
            }
            consoleItemsMap[consoleItemsKey] = originConsoleItems;
        }
        return NO;
    }
    
    if (!searchField) {
        return YES;
    }
    
    
    // store all console items.
    if (![originConsoleItems containsObjectForKey:@([obj timestamp])]) {
        [originConsoleItems addObject:obj forKey:@([obj timestamp])];
    }
    consoleItemsMap[consoleItemsKey] = originConsoleItems;
    
    if (searchField.stringValue.length == 0) {
        return YES;
    }
    
    // Remove prefix log pattern
    NSString *content = [obj content];
    NSRange range = NSMakeRange(0, content.length);
    
    NSRegularExpression *logRegex = logItemPrefixPattern();
    content = [logRegex stringByReplacingMatchesInString:content options:(NSRegularExpressionCaseInsensitive | NSRegularExpressionDotMatchesLineSeparators) range:range withTemplate:@""];

    // Test with user's regex pattern
    NSError *error;
    NSRegularExpression *regex = [MCLog filterPatternsMap][consoleItemsKey];
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
