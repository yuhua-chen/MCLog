//
//  MCLog.m
//  MCLog
//
//  Created by Michael Chen on 2014/8/1.
//  Copyright (c) 2014年 Yuhua Chen. All rights reserved.
//

#import "MCLog.h"
#import <objc/runtime.h>
#include <execinfo.h>

#define MCLOG_FLAG "MCLOG_FLAG"
#define kTagSearchField	99

#define MCLogger(fmt, ...) NSLog((@"[MCLog] %s(Line:%d) " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__)

#define NSColorWithHexRGB(rgb) [NSColor colorWithCalibratedRed:((rgb) >> 16 & 0xFF) / 255.f green:((rgb) >> 8 & 0xFF) / 255.f  blue:((rgb) & 0xFF) / 255.f  alpha:1.f]

@class MCLogIDEConsoleArea;

static NSMutableDictionary      *OriginConsoleItemsMap  = nil;
//static NSSearchField            *SearchField            = nil;
static NSMutableDictionary      *SearchPatternsDic      = nil;

NSSearchField *getSearchField(id consoleArea);
NSString *hash(id obj);

NSArray *backtraceStack();
void hookDVTTextStorage();
void hookIDEConsoleAdaptor();
void hookIDEConsoleArea();
void hookIDEConsoleItem();
NSRegularExpression * logItemPrefixPattern();
NSRegularExpression * escCharPattern();


typedef NS_ENUM(NSUInteger, MCLogLevel) {
    MCLogLevelVerbose = 0x1000,
    MCLogLevelInfo,
    MCLogLevelWarn,
    MCLogLevelError
};


/////////////////////////////////////////////////////////////////////////////////////
@interface MCOrderedMap : NSObject
@property (nonatomic, strong) NSMutableOrderedSet   *keys;
@property (nonatomic, strong) NSMutableArray        *items;

- (void)addObject:(id)object forKey:(id)key;
- (id)removeObjectForKey:(id)key;
- (id)objectForKey:(id)key;
- (BOOL)containsObjectForKey:(id)key;
- (NSArray *)OrderedKeys;
- (NSArray *)orderedItems;
@end

#define verifyMap() \
do{\
NSAssert(self.keys.count == self.items.count, @"keys and items are not matched!");\
}while(0)

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
    verifyMap();
    NSUInteger keyIndex = [self.keys indexOfObject:key];
    if (keyIndex == NSNotFound) {
        [self.keys addObject:key];
        keyIndex = [self.keys indexOfObject:key];
        [self.items addObject:object];
    } else {
        [self.items replaceObjectAtIndex:keyIndex withObject:object];
    }
}

- (id)removeObjectForKey:(id)key {
    verifyMap();
    NSUInteger keyIndex = [self.keys indexOfObject:key];
    if (keyIndex != NSNotFound) {
        [self.keys removeObject:key];
        id object = self.items[keyIndex];
        [self.items removeObjectAtIndex:keyIndex];
        return object;
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

@end

////////////////////////////////////////////////////////////////////////////////////
#pragma mark - NSSearchField (MCLog)
@interface NSSearchField (MCLog)
@property (nonatomic, strong) MCLogIDEConsoleArea *consoleArea;
@property (nonatomic, strong) NSTextView *consoleTextView;
@end

static const void *kMCLogConsoleTextViewKey;
static const void *kMCLogIDEConsoleAreaKey;

@implementation NSSearchField (MCLog)

- (void)setConsoleArea:(MCLogIDEConsoleArea *)consoleArea
{
	objc_setAssociatedObject(self, &kMCLogIDEConsoleAreaKey, consoleArea, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (MCLogIDEConsoleArea *)consoleArea
{
	return objc_getAssociatedObject(self, &kMCLogIDEConsoleAreaKey);
}

- (void)setConsoleTextView:(NSTextView *)consoleTextView
{
	objc_setAssociatedObject(self, &kMCLogConsoleTextViewKey, consoleTextView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSTextView *)consoleTextView
{
	return objc_getAssociatedObject(self, &kMCLogConsoleTextViewKey);
}

@dynamic consoleArea;
@dynamic consoleTextView;
@end


///////////////////////////////////////////////////////////////////////////////////
#pragma mark - MCIDEConsoleItem

@interface NSObject (MCIDEConsoleItem)
- (void)setLogLevel:(NSUInteger)loglevel;
- (NSUInteger)logLevel;

- (void)updateItemAttribute:(id)item;
@end

static const void *LogLevelAssociateKey;
@implementation NSObject (MCIDEConsoleItem)

- (void)setLogLevel:(NSUInteger)loglevel
{
    objc_setAssociatedObject(self, &LogLevelAssociateKey, @(loglevel), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSUInteger)logLevel
{
    return [objc_getAssociatedObject(self, &LogLevelAssociateKey) unsignedIntegerValue];
}



- (void)updateItemAttribute:(id)item
{
    NSError *error = nil;
    NSString *logText = [item valueForKey:@"content"];
    if ([[item valueForKey:@"error"] boolValue]) {
        logText = [NSString stringWithFormat:(LC_ESC @"[31m%@" LC_RESET), logText];
        [item setValue:logText forKey:@"content"];
        return;
    }
    
    if (![[item valueForKey:@"output"] boolValue] || [[item valueForKey:@"outputRequestedByUser"] boolValue]) {
        return;
    }
    
    NSRange prefixRange = [logItemPrefixPattern() rangeOfFirstMatchInString:logText options:0 range:NSMakeRange(0, logText.length)];
    if (prefixRange.location != 0 || logText.length <= prefixRange.length) {
        return;
    }

    static NSRegularExpression *ControlCharsPattern = nil;
    if (ControlCharsPattern == nil) {
        ControlCharsPattern = [NSRegularExpression regularExpressionWithPattern:LC_ESC@"\\[[\\d;]+m" options:0 error:&error];
        if (!ControlCharsPattern) {
            MCLogger(@"%@", error);
        }
    }
    NSString *content = [logText substringFromIndex:prefixRange.length];
    NSString *originalContent = [ControlCharsPattern stringByReplacingMatchesInString:content options:0 range:NSMakeRange(0, content.length) withTemplate:@""];
    
    if ([originalContent hasPrefix:@"-[VERBOSE]"]) {
        [item setLogLevel:MCLogLevelVerbose];
        content = [NSString stringWithFormat:(LC_ESC @"[34m%@" LC_RESET), content];
    }
    else if ([originalContent hasPrefix:@"-[INFO]"]) {
        [item setLogLevel:MCLogLevelInfo];
        content = [NSString stringWithFormat:(LC_ESC @"[32m%@" LC_RESET), content];
    }
    else if ([originalContent hasPrefix:@"-[WARN]"]) {
        [item setLogLevel:MCLogLevelWarn];
        content = [NSString stringWithFormat:(LC_ESC @"[33m%@" LC_RESET), content];
    }
    else if ([originalContent hasPrefix:@"-[ERROR]"]) {
        [item setLogLevel:MCLogLevelError];
        content = [NSString stringWithFormat:(LC_ESC @"[31m%@" LC_RESET), content];
    } else {
        static NSMutableArray *extraErrorPatterns = nil;
        if (extraErrorPatterns == nil) {
            extraErrorPatterns = [NSMutableArray array];
            for (NSString *patternStr in @[
                                           @"^\\s*\\*\\*\\* Terminating app due to uncaught exception '.+', reason: '[\\s\\S]+'\\n*\\*\\*\\* First throw call stack:\\s*\\n",
                                           @"^\\s*(\\+|-)\\[[a-zA-Z_]\\w*\\s[a-zA-Z_]\\w*[(:([a-zA-Z_]\\w*)?)]*\\]: unrecognized selector sent to (class|instance) [\\dxXa-fA-F]+",
                                           @"^\\s*\\*\\*\\* Assertion failure in (\\+|-)\\[[a-zA-Z_]\\w*\\s[a-zA-Z_]\\w*[(:([a-zA-Z_]\\w*)?)]*\\],",
                                           @"^\\s*\\*\\*\\* Terminating app due to uncaught exception of class '[a-zA-Z_]\\w+'"
                                           ]) {
                NSRegularExpression *r = [NSRegularExpression regularExpressionWithPattern:patternStr options:0 error:&error];
                if (!r) {
                    MCLogger(@"ERROR:%@", error);
                    continue;
                }
                [extraErrorPatterns addObject:r];
            }
        }
        for (NSRegularExpression *r in extraErrorPatterns) {
            if ([r matchesInString:originalContent options:0 range:NSMakeRange(0, originalContent.length)].count > 0) {
                content = [NSString stringWithFormat:(LC_ESC @"[31m%@" LC_RESET), content];
                break;
            }
        }
    }
    
    [item setValue:[[logText substringWithRange:prefixRange] stringByAppendingString:content] forKey:@"content"];
}

@end


static IMP IDEConsoleItemInitIMP = nil;
@interface MCIDEConsoleItem : NSObject
- (id)initWithAdaptorType:(id)arg1 content:(id)arg2 kind:(int)arg3;
@end

@implementation MCIDEConsoleItem

- (id)initWithAdaptorType:(id)arg1 content:(id)arg2 kind:(int)arg3
{
    id item = IDEConsoleItemInitIMP(self, _cmd, arg1, arg2, arg3);
    [self updateItemAttribute:item];
    //MCLogger(@"%@, logLevel:%zd, adaptorType:%@", item, [item logLevel], [item valueForKey:@"adaptorType"]);
    return item;
}


@end


///////////////////////////////////////////////////////////////////////////////////
#pragma mark - MCLogIDEConsoleArea
static IMP OriginalShouldAppendItem = nil;
@interface MCLogIDEConsoleArea : NSViewController
- (BOOL)_shouldAppendItem:(id)obj;
- (void)_clearText;
@end

static IMP OriginalClearTextIMP = nil;
@implementation MCLogIDEConsoleArea

- (BOOL)_shouldAppendItem:(id)obj;
{
	NSSearchField *searchField = getSearchField(self);
    if (!searchField.consoleArea) {
        searchField.consoleArea = self;
    }
    
    MCOrderedMap *originConsoleItems = OriginConsoleItemsMap[hash(self)];
    if (!originConsoleItems) {
        originConsoleItems = [[MCOrderedMap alloc] init];
    }
    
    NSInteger filterMode = [[self valueForKey:@"filterMode"] intValue];
    BOOL shouldShowLogLevel = YES;
    if (filterMode >= MCLogLevelVerbose) {
        shouldShowLogLevel = [obj logLevel] >= filterMode
        || [[obj valueForKey:@"input"] boolValue]
        || [[obj valueForKey:@"prompt"] boolValue]
        || [[obj valueForKey:@"outputRequestedByUser"] boolValue]
        || [[obj valueForKey:@"adaptorType"] hasSuffix:@".Debugger"];
    } else {
        shouldShowLogLevel = [OriginalShouldAppendItem(self, _cmd, obj) boolValue];
    }
    
    if (!shouldShowLogLevel) {
        if (searchField) {
            // store all console items.
            if (![originConsoleItems containsObjectForKey:@([obj timestamp])]) {
                [originConsoleItems addObject:obj forKey:@([obj timestamp])];
            }
            [OriginConsoleItemsMap setObject:originConsoleItems forKey:hash(self)];
        }
        return NO;
    }
    
	if (!searchField) {
		return YES;
	}
  
    
	// store all console items.
    if (![originConsoleItems containsObjectForKey:@([obj timestamp])]) {
        [originConsoleItems addObject:obj forKey:@([obj timestamp])];
    }
	[OriginConsoleItemsMap setObject:originConsoleItems forKey:hash(self)];
    
    if (searchField.stringValue.length == 0) {
        return YES;
    }
	
	// test with the regular expression
	NSString *content = [obj content];
	NSRange range = NSMakeRange(0, content.length);
    
    if (SearchPatternsDic == nil) {
        SearchPatternsDic = [NSMutableDictionary dictionary];
    }
    
    NSError *error;
    NSRegularExpression *regex = SearchPatternsDic[hash(self)];
    if (regex == nil || ![regex.pattern isEqualToString:searchField.stringValue]) {
        regex = [NSRegularExpression regularExpressionWithPattern:searchField.stringValue
                                                  options:(NSRegularExpressionCaseInsensitive|NSRegularExpressionDotMatchesLineSeparators)
                                                    error:&error];
        if (regex == nil) {
            // display all if with regex is error
            MCLogger(@"error:%@", error);
            return YES;
        }
        SearchPatternsDic[hash(self)] = regex;
    }
    
    
    NSArray *matches = [regex matchesInString:content options:0 range:range];	
	if ([matches count] > 0
        || [[obj valueForKey:@"input"] boolValue]
        || [[obj valueForKey:@"prompt"] boolValue]
        || [[obj valueForKey:@"outputRequestedByUser"] boolValue]
        || [[obj valueForKey:@"adaptorType"] hasSuffix:@".Debugger"]) {
		return YES;
	}

	return NO;
}

- (void)_clearText
{
	OriginalClearTextIMP(self, _cmd);
	[OriginConsoleItemsMap removeObjectForKey:hash(self)];
}
@end




///////////////////////////////////////////////////////////////////////////////////
#pragma mark - MCDVTTextStorage
static IMP OriginalFixAttributesInRangeIMP      = nil;

static void *kLastAttributeKey;
@interface MCDVTTextStorage : NSTextStorage
- (void)fixAttributesInRange:(NSRange)range;
@end

@interface NSObject (DVTTextStorage)
- (void)setLastAttribute:(NSDictionary *)attribute;
- (NSDictionary *)lastAttribute;
- (void)updateAttributes:(NSMutableDictionary *)attrs withANSIESCString:(NSString *)ansiEscString;
@end

@implementation MCDVTTextStorage

- (void)fixAttributesInRange:(NSRange)range
{
    OriginalFixAttributesInRangeIMP(self, _cmd, range);
    
    __block NSRange lastRange = NSMakeRange(range.location, 0);
    NSMutableDictionary *attrs = [NSMutableDictionary dictionary];
    if (self.lastAttribute.count > 0) {
        [attrs setValuesForKeysWithDictionary:self.lastAttribute];
    }

    [escCharPattern() enumerateMatchesInString:self.string options:0 range:range usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
        if (attrs.count > 0) {
            NSRange attrRange = NSMakeRange(lastRange.location, result.range.location - lastRange.location);
            [self addAttributes:attrs range:attrRange];
            //MCLogger(@"apply attributes:%@\nin range:[%zd, %zd], affected string:%@", attrs, attrRange.location, attrRange.length, [self.string substringWithRange:attrRange]);
        }
        
        NSString *attrsDesc = [self.string substringWithRange:[result rangeAtIndex:1]];
        if (attrsDesc.length == 0) {
            [self addAttributes:@{
                                  NSFontAttributeName: [NSFont systemFontOfSize:0.000001f],
                                  NSForegroundColorAttributeName: [NSColor clearColor]
                                 }
                          range:result.range];
            lastRange = result.range;
            return;
        }
        [self updateAttributes:attrs withANSIESCString:attrsDesc];
        [self addAttributes:@{
                              NSFontAttributeName: [NSFont systemFontOfSize:0.000001f],
                              NSForegroundColorAttributeName: [NSColor clearColor]
                              }
                      range:result.range];
        lastRange = result.range;
    }];
    self.lastAttribute = attrs;
}

@end

@implementation NSObject (DVTTextStorage)

- (void)setLastAttribute:(NSDictionary *)attribute
{
    objc_setAssociatedObject(self, &kLastAttributeKey, attribute, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSDictionary *)lastAttribute
{
    return objc_getAssociatedObject(self, &kLastAttributeKey);
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

@end

///////////////////////////////////////////////////////////////////////////////////
#pragma mark - MCIDEConsoleAdaptor
static IMP originalOutputForStandardOutputIMP = nil;

@interface MCIDEConsoleAdaptor :NSObject
- (void)outputForStandardOutput:(id)arg1 isPrompt:(BOOL)arg2 isOutputRequestedByUser:(BOOL)arg3;
@end


static const void *kUnProcessedOutputKey;
static const void *kTimerKey;

@interface NSObject (MCIDEConsoleAdaptor)
- (void)setUnprocessedOutput:(NSString *)output;
- (NSString *)unprocessedOutput;

- (void)setTimer:(NSTimer *)timer;
- (NSTimer *)timer;

- (void)timerTimeout:(NSTimer *)timer;
@end

@implementation NSObject (MCIDEConsoleAdaptor)

- (void)setUnprocessedOutput:(NSString *)output
{
    objc_setAssociatedObject(self, &kUnProcessedOutputKey, output, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSString *)unprocessedOutput
{
    return objc_getAssociatedObject(self, &kUnProcessedOutputKey);
}

- (void)setTimer:(NSTimer *)timer
{
    objc_setAssociatedObject(self, &kTimerKey, timer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSTimer *)timer
{
    return objc_getAssociatedObject(self, &kTimerKey);
}

- (void)timerTimeout:(NSTimer *)timer
{
    if (self.unprocessedOutput.length > 0) {
        NSArray *args = timer.userInfo;
        originalOutputForStandardOutputIMP(self, _cmd, self.unprocessedOutput, [args[0] boolValue], [args[1] boolValue]);
    }
    self.unprocessedOutput = nil;
}

@end


@implementation MCIDEConsoleAdaptor

- (void)outputForStandardOutput:(id)arg1 isPrompt:(BOOL)arg2 isOutputRequestedByUser:(BOOL)arg3
{
    [self.timer invalidate];
    self.timer = nil;
    
    NSRegularExpression *logSeperatorPattern = logItemPrefixPattern();

    NSString *unprocessedstring = self.unprocessedOutput;
    NSString *buffer = arg1;
    if (unprocessedstring.length > 0) {
        buffer = [unprocessedstring stringByAppendingString:arg1];
        self.unprocessedOutput = nil;
    }
    
    if (logSeperatorPattern) {
        NSArray *matches = [logSeperatorPattern matchesInString:buffer options:0 range:NSMakeRange(0, [buffer length])];
        if (matches.count > 0) {
            NSRange lastMatchingRange = NSMakeRange(NSNotFound, 0);
            for (NSTextCheckingResult *result in matches) {
                
                if (lastMatchingRange.location != NSNotFound) {
                    NSString *logItemData = [buffer substringWithRange:NSMakeRange(lastMatchingRange.location, result.range.location - lastMatchingRange.location)];
                    originalOutputForStandardOutputIMP(self, _cmd, logItemData, arg2, arg3);
                }
                lastMatchingRange = result.range;
            }
            if (lastMatchingRange.location + lastMatchingRange.length < [buffer length]) {
                self.unprocessedOutput = [buffer substringFromIndex:lastMatchingRange.location];
            }
        } else {
            originalOutputForStandardOutputIMP(self, _cmd, buffer, arg2, arg3);
        }
    } else {
        originalOutputForStandardOutputIMP(self, _cmd, arg1, arg2, arg3);
    }
    
    if (self.unprocessedOutput.length > 0) {
        self.timer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(timerTimeout:) userInfo:@[ @(arg2), @(arg3) ] repeats:NO];
    }
    
}

@end


///////////////////////////////////////////////////////////////////////////////////////////

@interface MCLog ()<NSTextFieldDelegate>
@end

@implementation MCLog

+ (void)load
{
    NSLog(@"%s, env: %s", __PRETTY_FUNCTION__, getenv(MCLOG_FLAG));
    
    if (getenv(MCLOG_FLAG) && !strcmp(getenv(MCLOG_FLAG), "YES")) {
        // alreay installed plugin
        return;
    }
    
    hookDVTTextStorage();
    hookIDEConsoleAdaptor();
    hookIDEConsoleArea();
    hookIDEConsoleItem();
    
    OriginConsoleItemsMap = [NSMutableDictionary dictionary];
    setenv(MCLOG_FLAG, "YES", 0);
}

+ (void)pluginDidLoad:(NSBundle *)bundle
{
    NSLog(@"%s, %@", __PRETTY_FUNCTION__, bundle);
    static id sharedPlugin = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedPlugin = [[self alloc] init];
    });
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (id)init
{
    self = [super init];
    if (self) {
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(activate:) name:@"IDEControlGroupDidChangeNotificationName" object:nil];
    }
    return self;
}

- (NSView *)getViewByClassName:(NSString *)className andContainerView:(NSView *)container
{
    Class class = NSClassFromString(className);
    for (NSView *subView in container.subviews) {
        if ([subView isKindOfClass:class]) {
            return subView;
        } else {
            NSView *view = [self getViewByClassName:className andContainerView:subView];
            if ([view isKindOfClass:class]) {
                return view;
            }
        }
    }
    return nil;
}

- (NSView *)getParantViewByClassName:(NSString *)className andView:(NSView *)view
{
    NSView *superView = view.superview;
    while (superView) {
        if ([[superView className] isEqualToString:className]) {
            return superView;
        }
        superView = superView.superview;
    }
    
    return nil;
}

- (BOOL)addCustomViews
{
    NSView *contentView = [[NSApp mainWindow] contentView];
    NSView *consoleTextView = [self getViewByClassName:@"IDEConsoleTextView" andContainerView:contentView];
    if (!consoleTextView) {
        return NO;
    }
    
    contentView = [self getParantViewByClassName:@"DVTControllerContentView" andView:consoleTextView];
    NSView *scopeBarView = [self getViewByClassName:@"DVTScopeBarView" andContainerView:contentView];
    if (!scopeBarView) {
        return NO;
    }
    
    NSButton *button = nil;
    NSPopUpButton *filterButton = nil;
    for (NSView *subView in scopeBarView.subviews) {
        if (button && filterButton) break;
        if (button == nil && [[subView className] isEqualToString:@"NSButton"]) {
            button = (NSButton *)subView;
        }
        else if (filterButton == nil && [[subView className] isEqualToString:@"NSPopUpButton"]) {
            filterButton = (NSPopUpButton *)subView;
        }
    }
    
    if (!button) {
        return NO;
    }
    
    if(filterButton) {
        [self filterPopupButton:filterButton addItemWithTitle:@"Verbose" tag:MCLogLevelVerbose];
        [self filterPopupButton:filterButton addItemWithTitle:@"Info" tag:MCLogLevelInfo];
        [self filterPopupButton:filterButton addItemWithTitle:@"Warn" tag:MCLogLevelWarn];
        [self filterPopupButton:filterButton addItemWithTitle:@"Error" tag:MCLogLevelError];
    }
    
    NSInteger selectedItem = [filterButton indexOfItemWithTag:[[consoleTextView valueForKey:@"logMode"] intValue]];
    if (selectedItem < 0 || selectedItem >= [filterButton numberOfItems]) {
        [filterButton selectItemAtIndex:0];
    }
    
    if ([scopeBarView viewWithTag:kTagSearchField]) {
        return YES;
    }
    
    NSRect frame = button.frame;
    frame.origin.x -= button.frame.size.width + 205;
    frame.size.width = 200.0;
    frame.size.height -= 2;
    
    NSSearchField *searchField = [[NSSearchField alloc] initWithFrame:frame];
    searchField.autoresizingMask = NSViewMinXMargin;
    searchField.font = [NSFont systemFontOfSize:11.0];
    searchField.delegate = self;
    searchField.consoleTextView = (NSTextView *)consoleTextView;
    searchField.tag = kTagSearchField;
    [searchField.cell setPlaceholderString:@"Regular Expression"];
    [scopeBarView addSubview:searchField];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(searchFieldDidEndEditing:) name:NSControlTextDidEndEditingNotification object:nil];
    
    return YES;
}

- (void)filterPopupButton:(NSPopUpButton *)popupButton addItemWithTitle:(NSString *)title tag:(NSUInteger)tag
{
    [popupButton addItemWithTitle:title];
    [popupButton itemAtIndex:popupButton.numberOfItems - 1].tag = tag;
}

#pragma mark - Notifications

- (void)searchFieldDidEndEditing:(NSNotification *)notification
{
    if (![[notification object] isMemberOfClass:[NSSearchField class]]) {
        return;
    }
    
    NSSearchField *searchField = [notification object];
    if (![searchField respondsToSelector:@selector(consoleTextView)]) {
        return;
    }
    
    if (![searchField respondsToSelector:@selector(consoleArea)]) {
        return;
    }
    
    NSTextView *consoleTextView = searchField.consoleTextView;
    MCLogIDEConsoleArea *consoleArea = searchField.consoleArea;
    
    // get rid of the annoying 'undeclared selector' warning
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
    if ([consoleTextView respondsToSelector:@selector(clearConsoleItems)]) {
        [consoleTextView performSelector:@selector(clearConsoleItems) withObject:nil];
    }

	NSString *cachedKey = hash(consoleArea);
	if (cachedKey) {
		NSArray *sortedItems = [OriginConsoleItemsMap[hash(consoleArea)] orderedItems];

		if ([consoleArea respondsToSelector:@selector(_appendItems:)]) {
			[consoleArea performSelector:@selector(_appendItems:) withObject:sortedItems];
		}

		[SearchPatternsDic removeObjectForKey:hash(consoleArea)];
	}
#pragma clang diagnostic pop
}

- (void)activate:(NSNotification *)notification
{
	[self addCustomViews];
}

@end

#pragma mark - method hookers

void hookIDEConsoleArea()
{
    Class IDEConsoleArea = NSClassFromString(@"IDEConsoleArea");
    //_shouldAppendItem
    Method shouldAppendItem = class_getInstanceMethod(IDEConsoleArea, @selector(_shouldAppendItem:));
    OriginalShouldAppendItem = method_getImplementation(shouldAppendItem);
    IMP hookedShouldAppendItemIMP = class_getMethodImplementation([MCLogIDEConsoleArea class], @selector(_shouldAppendItem:));
    method_setImplementation(shouldAppendItem, hookedShouldAppendItemIMP);
    
    //_clearText
    Method clearText = class_getInstanceMethod(IDEConsoleArea, @selector(_clearText));
    OriginalClearTextIMP = method_getImplementation(clearText);
    IMP newImpl = class_getMethodImplementation([MCLogIDEConsoleArea class], @selector(_clearText));
    method_setImplementation(clearText, newImpl);
}

void hookIDEConsoleItem()
{
    Class IDEConsoleItem = NSClassFromString(@"IDEConsoleItem");
    Method consoleItemInit = class_getInstanceMethod(IDEConsoleItem, @selector(initWithAdaptorType:content:kind:));
    IDEConsoleItemInitIMP = method_getImplementation(consoleItemInit);
    IMP newConsoleItemInit = class_getMethodImplementation([MCIDEConsoleItem class], @selector(initWithAdaptorType:content:kind:));
    method_setImplementation(consoleItemInit, newConsoleItemInit);
}

void hookDVTTextStorage()
{
    Class DVTTextStorage = NSClassFromString(@"DVTTextStorage");
    
    Method fixAttributesInRange = class_getInstanceMethod(DVTTextStorage, @selector(fixAttributesInRange:));
    OriginalFixAttributesInRangeIMP = method_getImplementation(fixAttributesInRange);
    IMP newFixAttributesInRangeIMP = class_getMethodImplementation([MCDVTTextStorage class], @selector(fixAttributesInRange:));
    method_setImplementation(fixAttributesInRange, newFixAttributesInRangeIMP);
}

void hookIDEConsoleAdaptor()
{
    Class IDEConsoleAdaptor = NSClassFromString(@"IDEConsoleAdaptor");
    Method outputForStandardOutput = class_getInstanceMethod(IDEConsoleAdaptor, @selector(outputForStandardOutput:isPrompt:isOutputRequestedByUser:));
    originalOutputForStandardOutputIMP = method_getImplementation(outputForStandardOutput);
    IMP newOutputForStandardOutputIMP = class_getMethodImplementation([MCIDEConsoleAdaptor class], @selector(outputForStandardOutput:isPrompt:isOutputRequestedByUser:));
    method_setImplementation(outputForStandardOutput, newOutputForStandardOutputIMP);
}

#pragma mark - util methods

NSRegularExpression * logItemPrefixPattern()
{
    static NSRegularExpression *pattern = nil;
    if (pattern == nil) {
        NSError *error = nil;
        pattern = [NSRegularExpression regularExpressionWithPattern:@"\\d{4}-\\d{2}-\\d{2}\\s\\d{2}:\\d{2}:\\d{2}[\\.:]\\d{3}\\s+.+\\[[\\da-fA-F]+:[\\da-fA-F]+\\]\\s+"
            options:NSRegularExpressionCaseInsensitive
              error:&error];
        if (!pattern) {
            MCLogger(@"%@", error);
        }
    }
    return pattern;
}

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

NSSearchField *getSearchField(id consoleArea)
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
	if (![consoleArea respondsToSelector:@selector(scopeBarView)]) {
		return nil;
	}
	
	NSView *scopeBarView = [consoleArea performSelector:@selector(scopeBarView) withObject:nil];
	return [scopeBarView viewWithTag:kTagSearchField];
#pragma clang diagnositc pop
}

NSString *hash(id obj)
{
	if (!obj) {
		return nil;
	}
	
    return [NSString stringWithFormat:@"%lx", (long)obj];
}


NSArray *backtraceStack()
{
    void* callstack[128];
    int frames = backtrace(callstack, 128);
    char **symbols = backtrace_symbols(callstack, frames);
    
    int i;
    NSMutableArray *backtrace = [NSMutableArray arrayWithCapacity:frames];
    for (i = 0; i < frames; ++i) {
        NSString *line = [NSString stringWithUTF8String:symbols[i]];
        if (line == nil) {
            break;
        }
        [backtrace addObject:line];
    }
    
    free(symbols);
    
    return backtrace;
}

