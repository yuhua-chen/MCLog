//
//  MCDVTTextStorage.h
//  MCLog
//
//  Created by Michael Chen on 2015/11/17.
//  Copyright © 2015年 Yuhua Chen. All rights reserved.
//

#import "MCXcodeHeaders.h"

@interface NSTextStorage (MCDVTTextStorage)

- (void)mc_fixAttributesInRange:(NSRange)range;
- (void)updateAttributes:(NSMutableDictionary *)attrs withANSIESCString:(NSString *)ansiEscString;

- (void)setLastAttribute:(NSDictionary *)attribute;
- (NSDictionary *)lastAttribute;
- (void)setConsoleStorage:(BOOL)consoleStorage;
- (BOOL)consoleStorage;

@end