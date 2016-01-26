//
//  PluginConfigs.m
//  MCLog
//
//  Created by Alex Lee on 1/7/16.
//  Copyright © 2016 Yuhua Chen. All rights reserved.
//

#import "PluginConfigs.h"

#define NSColorWithHexRGB(rgb) \
    [NSColor colorWithCalibratedRed:((rgb) >> 16 & 0xFF) / 255.f \
                              green:((rgb) >> 8  & 0xFF) / 255.f \
                               blue:((rgb)       & 0xFF) / 255.f \
                              alpha:1.f]

////////////////////////// configurations /////////////////////////
// clang-format off
// color tables                                         ANSI Codes
//bright colors  (default colors)               text color          background color
const UInt32 kBrightBlack  = 0x000000;         //  30                      40
const UInt32 kBrightRed    = 0xD70000;         //  31                      41
const UInt32 kBrightGreen  = 0x00FF00;         //  32                      42
const UInt32 kBrightYellow = 0xFFFF00;         //  33                      43
const UInt32 kBrightBlue   = 0x2E64FF;         //  34                      44
const UInt32 kBrightPurple = 0xFF00FF;         //  35                      45
const UInt32 kBrightCyan   = 0x00FFFF;         //  36                      46
const UInt32 kBrightWhite  = 0xFFFFFF;         //  37                      47

// normal (dark) colors (use ANSI code:2 to enable it.)
const UInt32 kDarkBlack  = 0x000000;
const UInt32 kDarkRed    = 0x800000;
const UInt32 kDarkGreen  = 0x008000;
const UInt32 kDarkYellow = 0x808000;
const UInt32 kDarkBlue   = 0x1C3D9B;
const UInt32 kDarkPurple = 0x800080;
const UInt32 kDarkCyan   = 0x008080;
const UInt32 kDarkWhite  = 0xC0C0C0;
// clang-format on

NSArray<NSColor *> *brightColors() {
    static NSArray<NSColor *> *kBrightColors;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        kBrightColors = @[
            NSColorWithHexRGB(kBrightBlack),
            NSColorWithHexRGB(kBrightRed),
            NSColorWithHexRGB(kBrightGreen),
            NSColorWithHexRGB(kBrightYellow),
            NSColorWithHexRGB(kBrightBlue),
            NSColorWithHexRGB(kBrightPurple),
            NSColorWithHexRGB(kBrightCyan),
            NSColorWithHexRGB(kBrightWhite)
        ];
    });
    return kBrightColors;
}

NSArray<NSColor *> *darkColors() {
    static NSArray<NSColor *> *kDarkColors;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        kDarkColors = @[
            NSColorWithHexRGB(kDarkBlack),
            NSColorWithHexRGB(kDarkRed),
            NSColorWithHexRGB(kDarkGreen),
            NSColorWithHexRGB(kDarkYellow),
            NSColorWithHexRGB(kDarkBlue),
            NSColorWithHexRGB(kDarkPurple),
            NSColorWithHexRGB(kDarkCyan),
            NSColorWithHexRGB(kDarkWhite)
        ];
    });
    return kDarkColors;
}

NSColor *ANSICodeToNSColor(NSInteger value, BOOL useBrightColor) {
    if ((value >= 30 && value <= 37) || (value >= 40 && value <= 47)) {
        NSInteger index = value % 10;
        NSArray *colors = useBrightColor ? brightColors() : darkColors();
        if (index >= 0 && index < colors.count) {
            return colors[index];
        }
    }
    return nil;
}

NSInteger NSColorToANSICode(NSColor *color) {
    NSInteger index = [brightColors() indexOfObject:color];
    if (index == NSNotFound) {
        index = [darkColors() indexOfObject:color];
    }
    if (index != NSNotFound) {
        return index + 30;
    }
    return index;
}

inline NSDictionary *errorLogAttributes() {
    return @{ NSForegroundColorAttributeName: ANSICodeToNSColor(31, useBrightColorStyle()) };
}

inline NSDictionary *warningLogAttributes() {
    return @{ NSForegroundColorAttributeName: ANSICodeToNSColor(33, useBrightColorStyle()) };
}

inline NSDictionary *infoLogAttributes() {
    return @{ NSForegroundColorAttributeName: ANSICodeToNSColor(32, useBrightColorStyle()) };
}

inline NSDictionary *verboseLogAttributes() {
    return @{ NSForegroundColorAttributeName: ANSICodeToNSColor(34, useBrightColorStyle()) };
}

BOOL useBrightColorStyle() {
    return YES;
}

