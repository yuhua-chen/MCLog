//
//  MCLog.h
//  MCLog
//
//  Created by Michael Chen on 2014/8/1.
//  Copyright (c) 2014年 Yuhua Chen. All rights reserved.
//

#import <Foundation/Foundation.h>

#if TARGET_OS_IPHONE
#define LC_ESC @"\xC2\xA0"
#else
#define LC_ESC @"\033"
#endif



// Reset colors
#define LC_RESET				LC_ESC @"[0m"

@interface MCLog : NSObject
+ (void)pluginDidLoad:(NSBundle *)bundle;
@end


