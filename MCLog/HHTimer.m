//
//  HHTimer.m
//  BusinessLayer
//
//  Created by lingaohe on 3/5/14.
//  Copyright (c) 2014 Baidu. All rights reserved.
//

#import "HHTimer.h"

@interface HHTimer ()
@property(nonatomic, readwrite, copy) dispatch_block_t block;
@property(nonatomic, readwrite, strong) dispatch_source_t source;
@property(nonatomic, strong) id internalUserInfo;
@end

@implementation HHTimer

#pragma mark-- Init
+ (HHTimer *)scheduledTimerWithTimeInterval:(NSTimeInterval)seconds
                              dispatchQueue:(dispatch_queue_t)queue
                                      block:(dispatch_block_t)block
                                   userInfo:(id)userInfo
                                    repeats:(BOOL)yesOrNo {
    NSParameterAssert(seconds);
    NSParameterAssert(block);

    HHTimer *timer = [[self alloc] init];
    timer.internalUserInfo = userInfo;
    timer.block = block;
    timer.source = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
    uint64_t nsec = (uint64_t)(seconds * NSEC_PER_SEC);
    dispatch_source_set_timer(timer.source, dispatch_time(DISPATCH_TIME_NOW, nsec), nsec, 0);
    void (^internalBlock)(void) = ^{
        if (!yesOrNo) {
            block();
            [timer invalidate];
        } else {
            block();
        }
    };
    dispatch_source_set_event_handler(timer.source, internalBlock);
    dispatch_resume(timer.source);
    return timer;
}


- (void)dealloc {
    [self invalidate];
}
#pragma mark--Action
- (void)fire {
    self.block();
}

- (void)invalidate {
    if (self.source) {
        dispatch_source_cancel(self.source);
#if !__has_feature(objc_arc)
        dispatch_release(self.source);
#endif
        self.source = nil;
    }
    self.block = nil;
}

#pragma mark-- State
- (BOOL)isValid {
    return (self.source != nil);
}

- (id)userInfo {
    return self.internalUserInfo;
}
@end
