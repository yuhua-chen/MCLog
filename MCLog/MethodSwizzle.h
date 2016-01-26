//
//  MethodSwizzle.h
//  MCLog
//
//  Created by Alex Lee on 1/6/16.
//  Copyright © 2016 Yuhua Chen. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SwizzleContext : NSObject

@property(nonatomic, weak) id  object;
@property(nonatomic)       SEL selector;
@property(nonatomic)       IMP originalIMP;
@property(nonatomic)       IMP swizzleIMP;

@end

@interface MethodSwizzleHelper : NSObject

+ (BOOL)swizzleMethodForClass:(Class)clazz
                     selector:(SEL)selector
               replacementIMP:(IMP)imp
                isClassMethod:(BOOL)isClassMethod;

+ (IMP)originalIMPForClass:(Class)object selector:(SEL)selector;

@end

NS_ASSUME_NONNULL_END
