//
//  MCIDEConsoleItem.m
//  MCLog
//
//  Created by Alex Lee on 1/6/16.
//  Copyright © 2016 Yuhua Chen. All rights reserved.
//

#import "MCIDEConsoleItem.h"
#import "Utils.h"
#import "MethodSwizzle.h"
#import <objc/runtime.h>

static const void *LogLevelAssociateKey;
@implementation NSObject (MCIDEConsoleItem)

- (void)setLogLevel:(NSUInteger)loglevel
{
    objc_setAssociatedObject(self, &LogLevelAssociateKey, @(loglevel), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSUInteger)logLevel
{
    return [objc_getAssociatedObject(self, &LogLevelAssociateKey) unsignedIntegerValue];
}



- (void)updateItemAttribute:(id)item
{
    NSError *error = nil;
    NSString *logText = [item valueForKey:@"content"];
    if ([[item valueForKey:@"error"] boolValue]) {
        logText = [NSString stringWithFormat:(LC_ESC @"[31m%@" LC_RESET), logText];
        [item setValue:logText forKey:@"content"];
        return;
    }
    
    if (![[item valueForKey:@"output"] boolValue] || [[item valueForKey:@"outputRequestedByUser"] boolValue]) {
        return;
    }
    
    if (!logText) {
        return;
    }
    
    NSRange prefixRange = [logItemPrefixPattern() rangeOfFirstMatchInString:logText options:0 range:NSMakeRange(0, logText.length)];
    if (prefixRange.location != 0 || logText.length <= prefixRange.length) {
        return;
    }
    
    static NSRegularExpression *ControlCharsPattern = nil;
    if (ControlCharsPattern == nil) {
        ControlCharsPattern = [NSRegularExpression regularExpressionWithPattern:LC_ESC@"\\[[\\d;]+m" options:0 error:&error];
        if (!ControlCharsPattern) {
            MCLogger(@"%@", error);
        }
    }
    NSString *content = [logText substringFromIndex:prefixRange.length];
    NSString *originalContent = [ControlCharsPattern stringByReplacingMatchesInString:content options:0 range:NSMakeRange(0, content.length) withTemplate:@""];
    
    if ([originalContent hasPrefix:@"-[VERBOSE]"]) {
        [item setLogLevel:MCLogLevelVerbose];
        content = [NSString stringWithFormat:(LC_ESC @"[34m%@" LC_RESET), content];
    }
    else if ([originalContent hasPrefix:@"-[INFO]"]) {
        [item setLogLevel:MCLogLevelInfo];
        content = [NSString stringWithFormat:(LC_ESC @"[32m%@" LC_RESET), content];
    }
    else if ([originalContent hasPrefix:@"-[WARN]"]) {
        [item setLogLevel:MCLogLevelWarn];
        content = [NSString stringWithFormat:(LC_ESC @"[33m%@" LC_RESET), content];
    }
    else if ([originalContent hasPrefix:@"-[ERROR]"]) {
        [item setLogLevel:MCLogLevelError];
        content = [NSString stringWithFormat:(LC_ESC @"[31m%@" LC_RESET), content];
    } else {
        static NSMutableArray *extraErrorPatterns = nil;
        if (extraErrorPatterns == nil) {
            extraErrorPatterns = [NSMutableArray array];
            for (NSString *patternStr in @[
                                           @"^\\s*\\*\\*\\* Terminating app due to uncaught exception '.+', reason: '[\\s\\S]+'\\n*\\*\\*\\* First throw call stack:\\s*\\n",
                                           @"^\\s*(\\+|-)\\[[a-zA-Z_]\\w*\\s[a-zA-Z_]\\w*[(:([a-zA-Z_]\\w*)?)]*\\]: unrecognized selector sent to (class|instance) [\\dxXa-fA-F]+",
                                           @"^\\s*\\*\\*\\* Assertion failure in (\\+|-)\\[[a-zA-Z_]\\w*\\s[a-zA-Z_]\\w*[(:([a-zA-Z_]\\w*)?)]*\\],",
                                           @"^\\s*\\*\\*\\* Terminating app due to uncaught exception of class '[a-zA-Z_]\\w+'"
                                           ]) {
                NSRegularExpression *r = [NSRegularExpression regularExpressionWithPattern:patternStr options:0 error:&error];
                if (!r) {
                    MCLogger(@"ERROR:%@", error);
                    continue;
                }
                [extraErrorPatterns addObject:r];
            }
        }
        for (NSRegularExpression *r in extraErrorPatterns) {
            if ([r matchesInString:originalContent options:0 range:NSMakeRange(0, originalContent.length)].count > 0) {
                content = [NSString stringWithFormat:(LC_ESC @"[31m%@" LC_RESET), content];
                break;
            }
        }
    }
    
    [item setValue:[[logText substringWithRange:prefixRange] stringByAppendingString:content] forKey:@"content"];
}

@end



@implementation MCIDEConsoleItem

- (id)initWithAdaptorType:(id)arg1 content:(id)arg2 kind:(int)arg3
{
    static IMP IDEConsoleItemInitIMP = nil;
    if (IDEConsoleItemInitIMP == nil) {
        Class clazz = NSClassFromString(@"IDEConsoleItem");
        SEL selector = @selector(initWithAdaptorType:content:kind:);
        IDEConsoleItemInitIMP = [MethodSwizzleHelper originalIMPForClass:clazz selector:selector];
    }
    
    id item = IDEConsoleItemInitIMP(self, _cmd, arg1, arg2, arg3);
    [self updateItemAttribute:item];
    //MCLogger(@"%@, logLevel:%zd, adaptorType:%@", item, [item logLevel], [item valueForKey:@"adaptorType"]);
    return item;
}


@end
