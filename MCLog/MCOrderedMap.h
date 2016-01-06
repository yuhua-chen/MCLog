//
//  MCOrderMap.h
//  MCLog
//
//  Created by Alex Lee on 1/6/16.
//  Copyright © 2016 Yuhua Chen. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MCOrderedMap<__covariant KeyType, __covariant ObjectType> : NSObject

@property(nonatomic) NSUInteger maximumnItemsCount;

- (void)addObject:(ObjectType)object forKey:(KeyType)key;

- (ObjectType)removeObjectForKey:(KeyType)key;

- (ObjectType)objectForKey:(KeyType)key;

- (BOOL)containsObjectForKey:(KeyType)key;

- (NSArray<KeyType> *)OrderedKeys;
- (NSArray<ObjectType> *)orderedItems;

@end

NS_ASSUME_NONNULL_END