//
//  MCLog.h
//  MCLog
//
//  Created by Michael Chen on 2014/8/1.
//  Copyright (c) 2014年 Yuhua Chen. All rights reserved.
//

@import Foundation;

@class MCOrderedMap;
@interface MCLog : NSObject

+ (void)pluginDidLoad:(NSBundle *)bundle;

+ (NSMutableDictionary<NSString *, MCOrderedMap *> *)consoleItemsMap;

+ (NSMutableDictionary<NSString *, NSRegularExpression *> *)filterPatternsMap;
@end


