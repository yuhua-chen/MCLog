//
//  TestViewController.m
//  MCLog
//
//  Created by Alex Lee on 2/25/15.
//  Copyright (c) 2015 Yuhua Chen. All rights reserved.
//

#import "TestViewController.h"

#define EnableColorLog 1

// clang-format off
#define PRETTY_FILE_NAME (__FILE__ ? [[NSString stringWithUTF8String:__FILE__] lastPathComponent] : @"")

#if DEBUG
#   if EnableColorLog
#       define __ALLog(LEVEL, fmt, ...) NSLog((@"-\e[7m" LEVEL @"\e[27;2;3;4m %s (%@:%d)\e[22;23;24m " fmt), __PRETTY_FUNCTION__, PRETTY_FILE_NAME, __LINE__, ##__VA_ARGS__)
#   else
#       define __ALLog(LEVEL, fmt, ...) NSLog((@" %s (%@:%d) " fmt), __PRETTY_FUNCTION__, PRETTY_FILE_NAME, __LINE__, ##__VA_ARGS__)
#   endif
#else
#   define __ALLog(LEVEL, fmt, ...) do {} while (0)
#endif
// clang-format on

#define ALLogVerbose(fmt, ...)  __ALLog(@"[VERBOSE]", fmt, ##__VA_ARGS__)
#define ALLogInfo(fmt, ...)     __ALLog(@"[INFO]", fmt, ##__VA_ARGS__)
#define ALLogWarn(fmt, ...)     __ALLog(@"[WARN]", fmt, ##__VA_ARGS__)
#define ALLogError(fmt, ...)    __ALLog(@"[ERROR]", fmt, ##__VA_ARGS__)

@implementation TestViewController

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self logTest];
    });
}

- (void)logTest {
    for (NSUInteger count = 0; count < 50000; ++count) {
        if (count % 1000 == 0) {
            [NSThread sleepForTimeInterval:0.1];
        }
        NSUInteger random = arc4random() % 4;
        NSUInteger randomStringLen = arc4random() % 200;
        NSMutableString *randomString = [NSMutableString stringWithCapacity:randomStringLen];
        for (NSUInteger i = 0; i < randomStringLen; ++i) {
            [randomString appendFormat:@"%02X", arc4random() % 256];
        }
        if (random == 0) {
            ALLogVerbose(@"***[%tu]***:If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.%@", count, randomString);
        } else if (random == 1) {
            ALLogInfo(@"***[%tu]***:Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.%@", count, randomString);
        } else if (random == 2) {
            ALLogWarn(@"***[%tu]***:If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.%@", count, randomString);
        } else if (random == 3) {
            ALLogError(@"***[%tu]***:Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.%@", count, randomString);
        }
    }
}

@end
