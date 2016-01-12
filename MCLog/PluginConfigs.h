//
//  PluginConfigs.h
//  MCLog
//
//  Created by Alex Lee on 1/7/16.
//  Copyright © 2016 Yuhua Chen. All rights reserved.
//

#import <Foundation/Foundation.h>


////////////////////////// configurations /////////////////////////
// clang-format off
// color tables                                         ANSI Codes
//bright colors  (default colors)               text color          background color
extern const UInt32 kBrightBlack;               //  30                      40
extern const UInt32 kBrightRed;                 //  31                      41
extern const UInt32 kBrightGreen;               //  32                      42
extern const UInt32 kBrightYellow;              //  33                      43
extern const UInt32 kBrightBlue;                //  34                      44
extern const UInt32 kBrightPurple;              //  35                      45
extern const UInt32 kBrightCyan;                //  36                      46
extern const UInt32 kBrightWhite;               //  37                      47

// normal (dark) colors (use ANSI code:2 to enable it.)
extern const UInt32 kDarkBlack; 
extern const UInt32 kDarkRed; 
extern const UInt32 kDarkGreen; 
extern const UInt32 kDarkYellow; 
extern const UInt32 kDarkBlue;
extern const UInt32 kDarkPurple; 
extern const UInt32 kDarkCyan; 
extern const UInt32 kDarkWhite; 
// clang-format on


extern NSColor *ANSICodeToNSColor(NSInteger value, BOOL useBrightColor);
extern NSInteger NSColorToANSICode(NSColor *color);

extern inline NSDictionary *errorLogAttributes();
extern inline NSDictionary *warningLogAttributes();
extern inline NSDictionary *infoLogAttributes();
extern inline NSDictionary *verboseLogAttributes();

extern BOOL useBrightColorStyle();
