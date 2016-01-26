//
//  MCDVTTextStorage.h
//  MCLog
//
//  Created by Michael Chen on 2015/11/17.
//  Copyright © 2015年 Yuhua Chen. All rights reserved.
//

#import "MCXcodeHeaders.h"

@interface NSTextStorage(MCDVTTextStorage)

@property(nonatomic, strong)                  NSDictionary *currentAttributes;
@property(nonatomic, getter=isConsoleStorage) BOOL          consoleStorage;

- (void)mc_fixAttributesInRange:(NSRange)range;

@end