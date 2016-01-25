//
//  MCOrderMap.m
//  MCLog
//
//  Created by Alex Lee on 1/6/16.
//  Copyright © 2016 Yuhua Chen. All rights reserved.
//

#import "MCOrderedMap.h"

#define verifyMap() \
do{\
    NSAssert(self.keys.count == self.items.count, @"keys and items are not matched!");\
}while(NO)

NS_ASSUME_NONNULL_BEGIN

@interface MCOrderedMap<__covariant KeyType, __covariant ObjectType> ()
@property (nonatomic, strong) NSMutableOrderedSet<KeyType>   *keys;
@property (nonatomic, strong) NSMutableArray<ObjectType>     *items;
@end

@implementation MCOrderedMap 

- (instancetype)init {
    self = [super init];
    if (self) {
        _keys   = [NSMutableOrderedSet orderedSet];
        _items  = [NSMutableArray array];
    }
    return self;
}

- (id)objectForKey:(id)key {
    verifyMap();
    NSUInteger keyIndex = [self.keys indexOfObject:key];
    if (keyIndex != NSNotFound) {
        return self.items[keyIndex];
    }
    return nil;
}

- (void)addObject:(id)object forKey:(id)key {
    NSParameterAssert(key != nil && object != nil);
    @synchronized(self) {
        verifyMap();
        //[self removeHeadItems];
        NSUInteger keyIndex = [self.keys indexOfObject:key];
        if (keyIndex == NSNotFound) {
            [self.keys addObject:key];
            [self.items addObject:object];
        } else {
            [self.items replaceObjectAtIndex:keyIndex withObject:object];
        }
    }
}

- (id)removeObjectForKey:(id)key {
    @synchronized(self) {
        verifyMap();
        NSUInteger keyIndex = [self.keys indexOfObject:key];
        if (keyIndex != NSNotFound) {
            [self.keys removeObject:key];
            id object = self.items[keyIndex];
            [self.items removeObjectAtIndex:keyIndex];
            return object;
        }
    }
    return nil;
}

- (BOOL)containsObjectForKey:(id)key {
    verifyMap();
    return [self.keys containsObject:key];
}


- (NSArray *)OrderedKeys {
    verifyMap();
    return [[self.keys array] copy];
}

- (NSArray *)orderedItems {
    verifyMap();
    return [self.items copy];
}

- (void)removeHeadItems {
    if (self.maximumnItemsCount == 0) {
        return;
    }
    
    NSInteger itemsToRemove = self.keys.count - self.maximumnItemsCount;
    if (itemsToRemove <= 0) {
        return;
    }
    NSRange range = NSMakeRange(0, itemsToRemove);
    [self.keys removeObjectsInRange:range];
    [self.items removeObjectsInRange:range];

}

@end

NS_ASSUME_NONNULL_END
