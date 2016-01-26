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
#import "PluginConfigs.h"
#import <objc/runtime.h>



static inline void updateItemAttribute(id item);

static const void *kLogLevelAssociateKey;
@implementation NSObject (MCIDEConsoleItem)

- (void)setLogLevel:(NSUInteger)loglevel {
    objc_setAssociatedObject(self, &kLogLevelAssociateKey, @(loglevel), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSUInteger)logLevel {
    return [objc_getAssociatedObject(self, &kLogLevelAssociateKey) unsignedIntegerValue];
}

@end



@implementation MCIDEConsoleItem

+ (void)load {
    Class clazz = NSClassFromString(@"IDEConsoleItem");
    SEL selector = @selector(initWithAdaptorType:content:kind:);
    IMP hookIMP = class_getMethodImplementation([MCIDEConsoleItem class], selector);
    
    [MethodSwizzleHelper swizzleMethodForClass:clazz
                                      selector:selector
                                replacementIMP:hookIMP
                                 isClassMethod:NO];
}

- (id)initWithAdaptorType:(id)arg1 content:(id)arg2 kind:(int)arg3
{
    static IMP IDEConsoleItemInitIMP = nil;
    if (IDEConsoleItemInitIMP == nil) {
        Class clazz = NSClassFromString(@"IDEConsoleItem");
        SEL selector = @selector(initWithAdaptorType:content:kind:);
        IDEConsoleItemInitIMP = [MethodSwizzleHelper originalIMPForClass:clazz selector:selector];
    }
    
    id item = IDEConsoleItemInitIMP(self, _cmd, arg1, arg2, arg3);
    updateItemAttribute(item);
    return item;
}

@end


static inline void updateItemAttribute(id item) {
    NSString *logText = [item valueForKey:@"content"];
    if (!logText) {
        return;
    }
    
    if ([[item valueForKey:@"error"] boolValue]) {
        logText = [NSString stringWithFormat:(LC_ESC @"[31m%@" LC_RESET), logText];
        [item setValue:logText forKey:@"content"];
        return;
    }
    
    if (![[item valueForKey:@"output"] boolValue] || [[item valueForKey:@"outputRequestedByUser"] boolValue]) {
        return;
    }

    static NSRegularExpression *prefixRegex = nil;
    if (prefixRegex == nil) {
        prefixRegex = logItemPrefixPattern();
    }
    NSRange prefixRange =
        [prefixRegex rangeOfFirstMatchInString:logText options:0 range:NSMakeRange(0, logText.length)];
    if (prefixRange.location != 0 || logText.length <= prefixRange.length) {
        return;
    }

    static NSRegularExpression *escRegex = nil;
    if (escRegex == nil) {
        escRegex = escCharPattern();
    }

    NSString *content         = [logText substringFromIndex:prefixRange.length];
    NSString *originalContent = [escRegex stringByReplacingMatchesInString:content
                                                                   options:0
                                                                     range:NSMakeRange(0, content.length)
                                                              withTemplate:@""];

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
        static NSRegularExpression *kCommonErrorLogPatterh;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            NSString *pattern =
            @"\\s*\\*\\*\\* Terminating app due to uncaught exception '.+', reason: '[\\s\\S]+'\\n*\\*\\*\\* First throw call stack:\\s*\\n|"
            @"\\s*(\\+|-)\\[[a-zA-Z_]\\w*\\s[a-zA-Z_]\\w*[(:([a-zA-Z_]\\w*)?)]*\\]: unrecognized selector sent to (class|instance) [\\dxXa-fA-F]+|"
            @"\\s*\\*\\*\\* Assertion failure in (\\+|-)\\[[a-zA-Z_]\\w*\\s[a-zA-Z_]\\w*[(:([a-zA-Z_]\\w*)?)]*\\],|"
            @"\\s*\\*\\*\\* Terminating app due to uncaught exception of class '[a-zA-Z_]\\w+'";
            NSError *error = nil;
            kCommonErrorLogPatterh = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:&error];
            if (kCommonErrorLogPatterh == nil) {
                MCLogger(@"ERROR:%@", error);
            }
        });
        if ([kCommonErrorLogPatterh matchesInString:originalContent options:0 range:NSMakeRange(0, originalContent.length)].count > 0) {
            content = [NSString stringWithFormat:(LC_ESC @"[31m%@" LC_RESET), content];
        }
    }
    content = [content stringByReplacingOccurrencesOfString:(@"\n" LC_RESET) withString:(LC_RESET @"\n")];
    [item setValue:[[logText substringWithRange:prefixRange] stringByAppendingString:content] forKey:@"content"];
}


