//
//  MCDVTTextStorage.m
//  MCLog
//
//  Created by Michael Chen on 2015/11/17.
//  Copyright © 2015年 Yuhua Chen. All rights reserved.
//

#import "MCDVTTextStorage.h"
#import "MethodSwizzle.h"
#import "PluginConfigs.h"
#import "NSView+MCLog.h"
#import "Utils.h"
#import <objc/runtime.h>


static inline NSColor *consoleTextViewBackgroundColor() {
    static NSColor *color = nil; //when NSApp.isActive == NO; backgroundColor would return nil
    
    NSView *contentView = [[NSApp mainWindow] contentView];
    NSTextView *consoleTextView = [contentView descendantViewByClassName:@"IDEConsoleTextView"];
    if (!consoleTextView) {
        return color;
    }
    if ([consoleTextView respondsToSelector:NSSelectorFromString(@"backgroundColor")]) {
        color = [consoleTextView valueForKey:@"backgroundColor"] ?: color;
    }
    return color;
}

static inline NSFont *convertFontStyle(NSFont *font, NSFontTraitMask mask) {
    if (font == nil) {
        return nil;
    }
    return [[NSFontManager sharedFontManager] fontWithFamily:font.familyName
                                                      traits:mask
                                                      weight:[[NSFontManager sharedFontManager] weightOfFont:font]
                                                        size:font.pointSize];
}


void swizzleDVTTextStorage() {
    Class DVTTextStorage                = NSClassFromString(@"DVTTextStorage");
    Method fixAttributesInRange         = class_getInstanceMethod(DVTTextStorage, @selector(fixAttributesInRange:));
    Method swizzledFixAttributesInRange = class_getInstanceMethod(DVTTextStorage, @selector(mc_fixAttributesInRange:));
    
    BOOL didAddMethod = class_addMethod(DVTTextStorage, @selector(fixAttributesInRange:),
                                        method_getImplementation(swizzledFixAttributesInRange),
                                        method_getTypeEncoding(swizzledFixAttributesInRange));
    if (didAddMethod) {
        class_replaceMethod(DVTTextStorage, @selector(mc_fixAttributesInRange:),
                            method_getImplementation(fixAttributesInRange),
                            method_getTypeEncoding(swizzledFixAttributesInRange));
    } else {
        method_exchangeImplementations(fixAttributesInRange, swizzledFixAttributesInRange);
    }
}

@implementation NSTextStorage (MCDVTTextStorage)

+ (void)load {
    swizzleDVTTextStorage();
}

- (void)mc_fixAttributesInRange:(NSRange)range {
    [self mc_fixAttributesInRange:range];

    if (!self.consoleStorage) {
        return;
    }

    __block NSRange lastRange  = NSMakeRange(range.location, 0);
    NSMutableDictionary *attrs = [NSMutableDictionary dictionary];
    if (self.currentAttributes.count > 0) {
        [attrs setValuesForKeysWithDictionary:self.currentAttributes];
    }

    static NSRegularExpression *regex = nil;
    if (regex == nil) {
        regex = escCharPattern();
    }
    [regex enumerateMatchesInString:self.string
                            options:0
                              range:range
                         usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {

                             NSMutableDictionary *formalAttrs =
                                 [NSMutableDictionary dictionaryWithCapacity:attrs.count];
                             [attrs enumerateKeysAndObjectsUsingBlock:^(id _Nonnull key, id _Nonnull obj,
                                                                        BOOL *_Nonnull stop) {
                                 if (![key hasPrefix:@"mc_"]) {
                                     formalAttrs[key] = obj;
                                 }
                             }];

                             if (formalAttrs.count > 0) {
                                 NSRange attrRange =
                                     NSMakeRange(lastRange.location + lastRange.length,
                                                 result.range.location - lastRange.location - lastRange.length);
                                 [self addAttributes:formalAttrs range:attrRange];
                             }

                             NSString *attrsDesc = [self.string substringWithRange:[result rangeAtIndex:1]];

                             if (attrsDesc.length > 0) {
                                 [self addAttributesWithANSIEscValue:attrsDesc toAttributes:attrs];
                             }

                             [self addAttributes:@{
                                 NSFontAttributeName : [NSFont systemFontOfSize:0.000001f],
                                 NSForegroundColorAttributeName : [NSColor clearColor]
                             }
                                           range:result.range];

                             lastRange = result.range;

                         }];
    self.currentAttributes = attrs;
}

- (NSFont *)defaultFont {
    static NSFont *font = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSDictionary *xcAttrs = [self attributesAtIndex:0 effectiveRange:nil];
        font = xcAttrs[NSFontAttributeName] ?: [NSFont systemFontOfSize:11.f];
    });
    return font;
}

- (NSColor *)defaultTextColor {
    static NSColor *color = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSDictionary *xcAttrs = [self attributesAtIndex:0 effectiveRange:nil];
        color = xcAttrs[NSForegroundColorAttributeName] ?: [NSColor blackColor];
    });
    return color;
}

- (NSColor *)defaultBackgroundColor {
    static NSColor *color = nil;
    if (color == nil) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            color = consoleTextViewBackgroundColor();
            if (color == nil) {
                NSDictionary *xcAttrs = [self attributesAtIndex:0 effectiveRange:nil];
                color = xcAttrs[NSBackgroundColorAttributeName] ?: [NSColor whiteColor];
            }
        });
    }
    return color;
}

// not fully test.
// the following implement is base on my test in terminal.app of OS X 10.11
- (void)addAttributesWithANSIEscValue:(NSString *)ansiEscString toAttributes:(NSMutableDictionary *)attrs {
    
    __block NSInteger fgColorCode = 0;
    __block NSInteger bgColorCode = 0;
    
    [[ansiEscString componentsSeparatedByString:@";"]
     enumerateObjectsUsingBlock:^(NSString *_Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
         NSInteger attCode = [obj integerValue];
         
         // 1/21; 3/23; 4/24         => Font style
         // 2/22; 7/27; 8/28; 39/49  => Color style
         switch (attCode) {
             case 0:
                 [attrs removeAllObjects];
                 break;
                 
             case 1: // bold
                 attrs[@"mc_font_bolded"] = @(YES);
                 break;
                 
             case 21: // unBold
                 [attrs removeObjectForKey:@"mc_font_bolded"];
                 break;
                 
             case 3: // italic
                 attrs[@"mc_font_is_italic"] = @(YES);
                 break;
                 
             case 23: // italic off
                 [attrs removeObjectForKey:@"mc_font_is_italic"];
                 break;
                 
             case 4:  // underline
             case 24: // underline off
                 attrs[NSUnderlineStyleAttributeName] = attCode == 4 ? @( NSUnderlineStyleSingle ) : @( NSUnderlineStyleNone );
                 break;
                 
             case 2: // Faint (decreased intensity)
                 attrs[@"mc_color_fainted"] = @(YES);
                 break;
                 
             case 22: // normal intensity
                 [attrs removeObjectForKey:@"mc_color_fainted"];
                 break;
                 
             case 7: // image negative
                 attrs[@"mc_image_negatived"] = @(YES);
                 break;
                 
             case 27: // image positive
                 [attrs removeObjectForKey:@"mc_image_negatived"];
                 break;
                 
             case 8: // Conceal
                 attrs[@"mc_text_concealed"] = @(YES);
                 break;
                 
             case 28: // Conceal off
                 [attrs removeObjectForKey:@"mc_text_concealed"];
                 break;
                 
             case 39: // reset text color
                 attrs[NSForegroundColorAttributeName] = [self defaultTextColor];
                 break;
                 
             case 49: // reset background color
                 attrs[NSBackgroundColorAttributeName] = [self defaultBackgroundColor];
                 break;
                 
             //foreground color
             case 30: //black
             case 31: // Red
             case 32: // Green
             case 33: // Yellow
             case 34: // Blue
             case 35: // purple
             case 36: // cyan
             case 37: // gray
                 fgColorCode = attCode;
                 break;
                 
             // background color
             case 40: //black
             case 41: // Red
             case 42: // Green
             case 43: // Yellow
             case 44: // Blue
             case 45: // purple
             case 46: // cyan
             case 47: // gray
                 bgColorCode = attCode;
                 break;
                 
             default:
                 break;
         }
     }];

    
    NSFont *font = [self defaultFont];
    NSFontTraitMask fontMask = 0;
    if ([attrs[@"mc_font_bolded"] boolValue]) {
        fontMask |= NSBoldFontMask;
    }
    if ([attrs[@"mc_font_is_italic"] boolValue]) {
        fontMask |= NSItalicFontMask;
    }
    attrs[NSFontAttributeName] = convertFontStyle(font, fontMask);
    
    BOOL isFaint = [attrs[@"mc_color_fainted"] boolValue];
    
    NSColor *fgColor = nil;
    NSColor *bgColor = nil;
    
    if (fgColorCode == 0) {
        fgColorCode = [attrs[@"mc_fgcolor_num"] integerValue];
    }
    if (bgColorCode == 0) {
        bgColorCode = [attrs[@"mc_bgcolor_num"] integerValue];
    }
    
    if (fgColorCode != 0) {
        attrs[@"mc_fgcolor_num"] = @(fgColorCode);
        fgColor = ANSICodeToNSColor(fgColorCode, useBrightColorStyle() && !isFaint);
    } else {
        fgColor = attrs[NSForegroundColorAttributeName];
    }
    
    if (bgColorCode != 0) {
        attrs[@"mc_bgcolor_num"] = @(bgColorCode);
        bgColor = ANSICodeToNSColor(bgColorCode, useBrightColorStyle() && !isFaint);
    } else {
        bgColor = attrs[NSBackgroundColorAttributeName];
    }
    
    if ([attrs[@"mc_image_negatived"] boolValue] && ![attrs[@"mc_image_negatived_set"] boolValue]) {
            NSColor *swap = fgColor;
            fgColor = bgColor;
            bgColor = swap;
        
        attrs[@"mc_image_negatived_set"] = @(YES);
    } else if ([attrs[@"mc_image_negatived_set"] boolValue]) {
            NSColor *swap = fgColor;
            fgColor = bgColor;
            bgColor = swap;
        
        [attrs removeObjectForKey:@"mc_image_negatived_set"];
    }
    
    if ([attrs[@"mc_text_concealed"] boolValue]) {
        attrs[@"mc_fgcolor_conceal"] = fgColor;
        fgColor = [NSColor clearColor];
    } else {
        fgColor = attrs[@"mc_fgcolor_conceal"] ?: fgColor;
        [attrs removeObjectForKey:@"mc_fgcolor_conceal"];
    }
    
    if (fgColor) {
        attrs[NSForegroundColorAttributeName] = fgColor;
    } else {
        [attrs removeObjectForKey:NSForegroundColorAttributeName];
    }
    if (bgColor) {
        attrs[NSBackgroundColorAttributeName] = bgColor;
    } else {
        [attrs removeObjectForKey:NSBackgroundColorAttributeName];
    }
}

- (void)setCurrentAttributes:(NSDictionary *)attributes {
    objc_setAssociatedObject(self, @selector(currentAttributes), attributes, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSDictionary *)currentAttributes {
    return objc_getAssociatedObject(self, @selector(currentAttributes));
}

- (void)setConsoleStorage:(BOOL)consoleStorage {
    objc_setAssociatedObject(self, @selector(isConsoleStorage), @(consoleStorage), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)isConsoleStorage {
    return [objc_getAssociatedObject(self, @selector(isConsoleStorage)) boolValue];
}

@end





