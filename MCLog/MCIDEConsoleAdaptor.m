//
//  MCIDEConsoleAdaptor.m
//  MCLog
//
//  Created by Alex Lee on 1/6/16.
//  Copyright © 2016 Yuhua Chen. All rights reserved.
//

#import "MCIDEConsoleAdaptor.h"
#import "HHTimer.h"
#import "Utils.h"
#import "MethodSwizzle.h"
#import <objc/runtime.h>

static const void *kUnProcessedOutputKey;
static const void *kUnProcessedOutputTimerKey;

static dispatch_queue_t buffer_queue() {
    static dispatch_queue_t mclog_buffer_queue = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        mclog_buffer_queue = dispatch_queue_create("io.michaelchen.mclog.buffer-queue", DISPATCH_QUEUE_SERIAL);
    });
    
    return mclog_buffer_queue;
}


@implementation NSObject (MCIDEConsoleAdaptor)

- (void)setTimer:(HHTimer *)timer {
    objc_setAssociatedObject(self, &kUnProcessedOutputTimerKey, timer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (HHTimer *)timer {
    return objc_getAssociatedObject(self, &kUnProcessedOutputTimerKey);
}

- (void)setUnprocessedOutputInfo:(NSDictionary *)outputInfo
{
    objc_setAssociatedObject(self, &kUnProcessedOutputKey, outputInfo, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSDictionary *)unprocessedOutputInfo
{
    return objc_getAssociatedObject(self, &kUnProcessedOutputKey);
}

- (IMP)originalOutputIMP {
    static IMP originalIMP = nil;
    if (originalIMP == nil) {
        Class clazz = NSClassFromString(@"IDEConsoleAdaptor");
        SEL selector = @selector(outputForStandardOutput:isPrompt:isOutputRequestedByUser:);
        originalIMP = [MethodSwizzleHelper originalIMPForClass:clazz selector:selector];
    }
    return originalIMP;
}

- (void)mc_outputUnprocessedBuffer
{
    NSDictionary *unprocessedOutputInfo = self.unprocessedOutputInfo;
    if (unprocessedOutputInfo) {
        [self setUnprocessedOutputInfo:nil];

        [self originalOutputIMP](self, _cmd, [unprocessedOutputInfo[@"content"] stringValue],
                                 [unprocessedOutputInfo[@"isPrompt"] boolValue],
                                 [unprocessedOutputInfo[@"isOutputRequestedByUser"] boolValue]);
    }
}

- (void)invokeOriginalOutput:(id)arg1 isPrompt:(BOOL)arg2 isOutputRequestedByUser:(BOOL)arg3 {
    dispatch_async(buffer_queue(), ^{
        [self originalOutputIMP](self, _cmd, arg1, arg2, arg3);
    });
}

@end


@implementation MCIDEConsoleAdaptor

- (void)outputForStandardOutput:(id)arg1 isPrompt:(BOOL)arg2 isOutputRequestedByUser:(BOOL)arg3
{
    [self.timer invalidate];
    self.timer = nil;
    
    NSRegularExpression *logSeperatorPattern = logItemPrefixPattern();
    
    NSString *unprocessedString = self.unprocessedOutputInfo[@"content"];
    [self setUnprocessedOutputInfo:nil];
    
    NSString *buffer = arg1;
    if (unprocessedString.length > 0) {
        buffer = [unprocessedString stringByAppendingString:arg1];
    }

    if (logSeperatorPattern) {
        NSArray *matches = [logSeperatorPattern matchesInString:buffer options:0 range:NSMakeRange(0, [buffer length])];
        if (matches.count > 0) {
            NSRange lastMatchingRange = NSMakeRange(NSNotFound, 0);
            for (NSTextCheckingResult *result in matches) {
                if (lastMatchingRange.location != NSNotFound) {
                    NSString *logItemData =
                        [buffer substringWithRange:NSMakeRange(lastMatchingRange.location,
                                                               result.range.location - lastMatchingRange.location)];
                    
                    [self invokeOriginalOutput:logItemData isPrompt:arg2 isOutputRequestedByUser:arg3];
                }
                lastMatchingRange = result.range;
            }

            if (lastMatchingRange.location + lastMatchingRange.length < [buffer length]) {
                unprocessedString = [buffer substringFromIndex:lastMatchingRange.location];
            }

        } else {
            [self invokeOriginalOutput:buffer isPrompt:arg2 isOutputRequestedByUser:arg3];
        }
    } else {
        [self invokeOriginalOutput:arg1 isPrompt:arg2 isOutputRequestedByUser:arg3];
    }

    if (unprocessedString.length > 0) {
        [self setUnprocessedOutputInfo:@{
            @"content":     unprocessedString,
            @"isPrompt":    @(arg2),
            @"isOutputRequestedByUser": @(arg3)
        }];

        self.timer = [HHTimer scheduledTimerWithTimeInterval:0.05
                                               dispatchQueue:buffer_queue()
                                                       block:^{
                                                           [self mc_outputUnprocessedBuffer];
                                                       }
                                                    userInfo:nil
                                                     repeats:NO];
    }
    
}

@end