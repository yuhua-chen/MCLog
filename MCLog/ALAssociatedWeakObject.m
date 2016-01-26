//
//  ALAssociatedWeakObject.m
//  MCLog
//
//  Created by Alex Lee on 1/9/16.
//  Copyright © 2016 Yuhua Chen. All rights reserved.
//

#import "ALAssociatedWeakObject.h"
#import <objc/runtime.h>

typedef void (^deallocBlock)(void);

@interface ALAssociatedWeakObject : NSObject

+ (instancetype)weakAssociatedObjectWithDeallocCallback:(deallocBlock)block;

@end

@implementation ALAssociatedWeakObject {
    deallocBlock _block;
}

+ (instancetype)weakAssociatedObjectWithDeallocCallback:(deallocBlock)block {
    return [[self alloc] initWithDeallocCallback:block];
}

- (instancetype)initWithDeallocCallback:(deallocBlock)block {
    self = [super init];
    if (self) {
        _block = [block copy];
    }
    return self;
}

- (void)dealloc {
    if (_block) {
        _block();
    }
}

@end


@implementation NSObject (AssociatedWeakObject)
static const char kRunAtDeallocBlockKey;
- (void)mc_runAtDealloc:(void(^)(void))block {
    if (block) {
        ALAssociatedWeakObject *proxy = [ALAssociatedWeakObject weakAssociatedObjectWithDeallocCallback:block];
        objc_setAssociatedObject(self,
                                 &kRunAtDeallocBlockKey,
                                 proxy,
                                 OBJC_ASSOCIATION_RETAIN);
    }
}

@end
