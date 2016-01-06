//
//  MethodSwizzle.m
//  MCLog
//
//  Created by Alex Lee on 1/6/16.
//  Copyright © 2016 Yuhua Chen. All rights reserved.
//

#import <objc/runtime.h>
#import "MethodSwizzle.h"

NS_ASSUME_NONNULL_BEGIN

@implementation SwizzleContext
@end

@implementation MethodSwizzleHelper

+ (NSMutableDictionary<NSString *, SwizzleContext *> *)swizzleMethods {
    static NSMutableDictionary<NSString *, SwizzleContext *> *kSwizzleMethods;

    if (kSwizzleMethods == nil) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            kSwizzleMethods = [NSMutableDictionary dictionary];
        });
    }
    return kSwizzleMethods;
}

+ (NSString *)contextKeyForClass:(Class)clazz selector:(SEL)selector {
    return [NSString stringWithFormat:@"%@:[%@]", NSStringFromClass(clazz), NSStringFromSelector(selector)];
}

+ (BOOL)swizzleMethodForClass:(Class)clazz
                     selector:(SEL)selector
               replacementIMP:(IMP)imp
                isClassMethod:(BOOL)isClassMethod {
    Method method = isClassMethod ? class_getClassMethod(clazz, selector) : class_getInstanceMethod(clazz, selector);
    if (method == nil) {
        return NO;
    }

    IMP originalIMP = method_setImplementation(method, imp);

    SwizzleContext *context = [[SwizzleContext alloc] init];
    context.object          = clazz;
    context.selector        = selector;
    context.originalIMP     = originalIMP;
    context.swizzleIMP      = imp;

    [self swizzleMethods][[self contextKeyForClass:clazz selector:selector]] = context;

    return YES;
}

+ (IMP)originalIMPForClass:(Class)object selector:(SEL)selector {
    SwizzleContext *context = [self swizzleMethods][[self contextKeyForClass:object selector:selector]];
    if (context == nil) {
        return nil;
    }
    return context.originalIMP;
}

@end

NS_ASSUME_NONNULL_END
