//
//  MCDVTTextStorage.m
//  MCLog
//
//  Created by Michael Chen on 2015/11/17.
//  Copyright © 2015年 Yuhua Chen. All rights reserved.
//

#import "MCDVTTextStorage.h"
#import "MethodSwizzle.h"
#import <objc/runtime.h>

#define NSColorWithHexRGB(rgb) [NSColor colorWithCalibratedRed:((rgb) >> 16 & 0xFF) / 255.f green:((rgb) >> 8 & 0xFF) / 255.f  blue:((rgb) & 0xFF) / 255.f  alpha:1.f]

NSRegularExpression * escCharPattern();

//@interface NSObject (MCDVTTextStorage_Extension)
//@property(nonatomic, readonly) NSString *string;
//
//- (void)addAttributes:(NSDictionary<NSString *, id> *)attrs range:(NSRange)range;
//@end

@implementation NSTextStorage (MCDVTTextStorage)

- (void)mc_fixAttributesInRange:(NSRange)range
{
//    MCLogger(@"\nstring:%@", self.string);
//    IMP originalIMP = nil;
//    if (originalIMP == nil) {
//        Class clazz = NSClassFromString(@"DVTTextStorage");
//        originalIMP = [MethodSwizzleHelper originalIMPForClass:clazz selector:@selector(fixAttributesInRange:)];
//    }
//    if (originalIMP) {
//        originalIMP(self, _cmd, range);
//    }
    
    [self mc_fixAttributesInRange:range];

	if (!self.consoleStorage) {
		return;
	}

	__block NSRange lastRange = NSMakeRange(range.location, 0);
	NSMutableDictionary *attrs = [NSMutableDictionary dictionary];
	if (self.lastAttribute.count > 0) {
		[attrs setValuesForKeysWithDictionary:self.lastAttribute];
	}

    [escCharPattern()
        enumerateMatchesInString:self.string
                         options:0
                           range:range
                      usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
                          if (attrs.count > 0) {
                              NSRange attrRange =
                                  NSMakeRange(lastRange.location, result.range.location - lastRange.location);
                              [self addAttributes:attrs range:attrRange];
                              // MCLogger(@"apply attributes:%@\nin range:[%zd, %zd], affected string:%@", attrs,
                              // attrRange.location, attrRange.length, [self.string substringWithRange:attrRange]);
                          }

                          NSString *attrsDesc = [self.string substringWithRange:[result rangeAtIndex:1]];
                          if (attrsDesc.length == 0) {
                              [self addAttributes:@{
                                  NSFontAttributeName : [NSFont systemFontOfSize:0.000001f],
                                  NSForegroundColorAttributeName : [NSColor clearColor]
                              }
                                            range:result.range];
                              lastRange = result.range;
                              return;
                          }
                          [self updateAttributes:attrs withANSIESCString:attrsDesc];
                          [self addAttributes:@{
                              NSFontAttributeName : [NSFont systemFontOfSize:0.000001f],
                              NSForegroundColorAttributeName : [NSColor clearColor]
                          }
                                        range:result.range];
                          lastRange = result.range;
                      }];
    self.lastAttribute = attrs;
}

- (void)updateAttributes:(NSMutableDictionary *)attrs withANSIESCString:(NSString *)ansiEscString
{
	NSArray *attrComponents = [ansiEscString componentsSeparatedByString:@";"];
	for (NSString *attrName in attrComponents) {
		NSUInteger attrCode = [attrName integerValue];
		switch (attrCode) {
			case 0:
				[attrs removeAllObjects];
				break;

			case 1:
				[attrs setObject:[NSFont boldSystemFontOfSize:11.f] forKey:NSFontAttributeName];
				break;

			case 4:
				[attrs setObject:@( NSUnderlineStyleSingle ) forKey:NSUnderlineStyleAttributeName];
				break;

			case 24:
				[attrs setObject:@(NSUnderlineStyleNone ) forKey:NSUnderlineStyleAttributeName];
				break;
				//foreground color
			case 30: //black
				[attrs setObject:[NSColor blackColor] forKey:NSForegroundColorAttributeName];
				break;

			case 31: // Red
				[attrs setObject:NSColorWithHexRGB(0xd70000) forKey:NSForegroundColorAttributeName];
				break;

			case 32: // Green
				[attrs setObject:NSColorWithHexRGB(0x00ff00) forKey:NSForegroundColorAttributeName];
				break;

			case 33: // Yellow
				[attrs setObject:NSColorWithHexRGB(0xffff00) forKey:NSForegroundColorAttributeName];
				break;

			case 34: // Blue
				[attrs setObject:NSColorWithHexRGB(0x005fff) forKey:NSForegroundColorAttributeName];
				break;

			case 35: // purple
				[attrs setObject:NSColorWithHexRGB(0xff00ff) forKey:NSForegroundColorAttributeName];
				break;

			case 36: // cyan
				[attrs setObject:NSColorWithHexRGB(0x00ffff) forKey:NSForegroundColorAttributeName];
				break;

			case 37: // gray
				[attrs setObject:NSColorWithHexRGB(0x808080) forKey:NSForegroundColorAttributeName];
				break;
				//background color
			case 40: //black
				[attrs setObject:[NSColor blackColor] forKey:NSBackgroundColorAttributeName];
				break;

			case 41: // Red
				[attrs setObject:NSColorWithHexRGB(0xd70000) forKey:NSBackgroundColorAttributeName];
				break;

			case 42: // Green
				[attrs setObject:NSColorWithHexRGB(0x00ff00) forKey:NSBackgroundColorAttributeName];
				break;

			case 43: // Yellow
				[attrs setObject:NSColorWithHexRGB(0xffff00) forKey:NSBackgroundColorAttributeName];
				break;

			case 44: // Blue
				[attrs setObject:NSColorWithHexRGB(0x005fff) forKey:NSBackgroundColorAttributeName];
				break;

			case 45: // purple
				[attrs setObject:NSColorWithHexRGB(0xff00ff) forKey:NSBackgroundColorAttributeName];
				break;

			case 46: // cyan
				[attrs setObject:NSColorWithHexRGB(0x00ffff) forKey:NSBackgroundColorAttributeName];
				break;

			case 47: // gray
				[attrs setObject:NSColorWithHexRGB(0x808080) forKey:NSBackgroundColorAttributeName];
				break;

			default:
				break;
		}
	}
}

- (void)setLastAttribute:(NSDictionary *)attribute
{
	objc_setAssociatedObject(self, @selector(lastAttribute), attribute, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSDictionary *)lastAttribute
{
	return objc_getAssociatedObject(self, @selector(lastAttribute));
}


- (void)setConsoleStorage:(BOOL)consoleStorage
{
    objc_setAssociatedObject(self, @selector(consoleStorage), @(consoleStorage), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)consoleStorage
{
    return [objc_getAssociatedObject(self, @selector(consoleStorage)) boolValue];
}

@end

#pragma mark - Utilities

NSRegularExpression * escCharPattern()
{
	static NSRegularExpression *pattern = nil;
	if (pattern == nil) {
		NSError *error = nil;
		pattern = [NSRegularExpression regularExpressionWithPattern:(LC_ESC @"\\[([\\d;]*\\d+)m") options:0 error:&error];
		if (!pattern) {
			MCLogger(@"%@", error);
		}
	}
	return pattern;
}
