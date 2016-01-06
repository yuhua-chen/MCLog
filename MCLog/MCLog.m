//
//  MCLog.m
//  MCLog
//
//  Created by Michael Chen on 2014/8/1.
//  Copyright (c) 2014年 Yuhua Chen. All rights reserved.
//

#include <execinfo.h>
#import <objc/runtime.h>
#import "HHTimer.h"
#import "MCDVTTextStorage.h"
#import "MCLog.h"
#import "MCOrderedMap.h"
#import "MCXcodeHeaders.h"
#import "NSView+MCLog.h"
#import "MCIDEConsoleItem.h"
#import "NSSearchField+MCLog.h"
#import "Utils.h"
#import "MCLogIDEConsoleArea.h"
#import "MCIDEConsoleAdaptor.h"
#import "MCDVTTextStorage.h"
#import "MethodSwizzle.h"

NS_ASSUME_NONNULL_BEGIN


#pragma mark - method swizzle

void hookIDEConsoleArea() {
    Class clazz = NSClassFromString(@"IDEConsoleArea");
    IMP hookedShouldAppendItemIMP = class_getMethodImplementation([MCLogIDEConsoleArea class],
                                                                  @selector(_shouldAppendItem:));
    
    [MethodSwizzleHelper swizzleMethodForClass:clazz
                                      selector:@selector(_shouldAppendItem:)
                                replacementIMP:hookedShouldAppendItemIMP
                                 isClassMethod:NO];
    
    IMP hookClearTextIMP = class_getMethodImplementation([MCLogIDEConsoleArea class], @selector(_clearText));
    [MethodSwizzleHelper swizzleMethodForClass:clazz
                                      selector:@selector(_clearText)
                                replacementIMP:hookClearTextIMP
                                 isClassMethod:NO];
}

void hookIDEConsoleItem()
{
    Class clazz = NSClassFromString(@"IDEConsoleItem");
    SEL selector = @selector(initWithAdaptorType:content:kind:);
    IMP hookIMP = class_getMethodImplementation([MCIDEConsoleItem class], selector);
    
    [MethodSwizzleHelper swizzleMethodForClass:clazz
                                      selector:selector
                                replacementIMP:hookIMP
                                 isClassMethod:NO];
}

//void hookDVTTextStorage()
//{
//    Class DVTTextStorage = NSClassFromString(@"DVTTextStorage");
//    IMP hookIMP = class_getMethodImplementation([MCDVTTextStorage class], @selector(fixAttributesInRange:));
//    
//    [MethodSwizzleHelper swizzleMethodForClass:DVTTextStorage
//                                      selector:@selector(fixAttributesInRange:)
//                                replacementIMP:hookIMP
//                                 isClassMethod:NO];
//}

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

void hookIDEConsoleAdaptor()
{
    Class clazz = NSClassFromString(@"IDEConsoleAdaptor");
    SEL selector = @selector(outputForStandardOutput:isPrompt:isOutputRequestedByUser:);
    IMP hookIMP = class_getMethodImplementation([MCIDEConsoleAdaptor class], selector);
    [MethodSwizzleHelper swizzleMethodForClass:clazz
                                      selector:selector
                                replacementIMP:hookIMP
                                 isClassMethod:NO];
}


@implementation MCLog

+ (void)load {
    NSLog(@"%s, env: %s", __PRETTY_FUNCTION__, getenv(MCLOG_FLAG));

    if (getenv(MCLOG_FLAG) && !strcmp(getenv(MCLOG_FLAG), "YES")) {
        // alreay installed plugin
        return;
    }

    //hookDVTTextStorage();
    swizzleDVTTextStorage();
    hookIDEConsoleAdaptor();
    hookIDEConsoleArea();
    hookIDEConsoleItem();
    
    setenv(MCLOG_FLAG, "YES", 0);
}

+ (void)pluginDidLoad:(NSBundle *)bundle {
    MCLogger(@"%s, %@", __PRETTY_FUNCTION__, bundle);
    static id sharedPlugin = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedPlugin = [[self alloc] init];
    });
}

+ (NSMutableDictionary<NSString *, MCOrderedMap *> *)consoleItemsMap {
    static NSMutableDictionary<NSString *, MCOrderedMap *> *dict = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dict = [NSMutableDictionary dictionary];
    });
    return dict;
}

+ (NSMutableDictionary<NSString *, NSRegularExpression *> *)filterPatternsMap {
    static NSMutableDictionary<NSString *, NSRegularExpression *> *dict = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dict = [NSMutableDictionary dictionary];
    });
    return dict;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (id)init {
    self = [super init];
    if (self) {
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(activate:)
                                                     name:@"IDEControlGroupDidChangeNotificationName"
                                                   object:nil];
    }
    return self;
}

#pragma mark - init UI

- (BOOL)addCustomViews {
    NSView *contentView         = [[NSApp mainWindow] contentView];
    NSTextView *consoleTextView = [contentView descendantViewByClassName:@"IDEConsoleTextView"];
    if (!consoleTextView) {
        return NO;
    }
    DVTTextStorage *textStorage = [consoleTextView valueForKey:@"textStorage"];
    if ([textStorage respondsToSelector:@selector(setConsoleStorage:)]) {
        [textStorage setConsoleStorage:YES];
    }

    contentView          = [consoleTextView ancestralViewByClassName:@"DVTControllerContentView"];
    NSView *scopeBarView = [contentView descendantViewByClassName:@"DVTScopeBarView"];
    if (!scopeBarView) {
        return NO;
    }
    

    [self addLogLevelButtonItemsAt:scopeBarView defaultLogLevel:[[consoleTextView valueForKey:@"logMode"] intValue]];
    [self addLogFilterPatternTextFieldAt:scopeBarView associateWith:consoleTextView];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(searchFieldDidEndEditing:)
                                                 name:NSControlTextDidEndEditingNotification
                                               object:nil];

    return YES;
}

- (BOOL)addLogLevelButtonItemsAt:(NSView *)scopeBarView defaultLogLevel:(MCLogLevel)level{
    NSPopUpButton *filterButton = nil;
    for (__kindof NSView *subView in scopeBarView.subviews) {
        if ([[subView className] isEqualToString:@"NSPopUpButton"]) {
            filterButton = subView;
            break;
        }
    }
    MCLogger(@"filterButton: %@", filterButton);
    if (filterButton) {
        [self filterPopupButton:filterButton addItemWithTitle:@"Verbose" tag:MCLogLevelVerbose];
        [self filterPopupButton:filterButton addItemWithTitle:@"Info" tag:MCLogLevelInfo];
        [self filterPopupButton:filterButton addItemWithTitle:@"Warn" tag:MCLogLevelWarn];
        [self filterPopupButton:filterButton addItemWithTitle:@"Error" tag:MCLogLevelError];
        
        if (level >= MCLogLevelVerbose && level <= MCLogLevelError) {
            [filterButton selectItemWithTag:level];
        }
    }
    return YES;
}

- (void)filterPopupButton:(NSPopUpButton *)popupButton addItemWithTitle:(NSString *)title tag:(NSUInteger)tag {
    [popupButton addItemWithTitle:title];
    [popupButton itemAtIndex:popupButton.numberOfItems - 1].tag = tag;
}

- (BOOL)addLogFilterPatternTextFieldAt:(NSView *)scopeBarView associateWith:(NSTextView *)consoleTextView {
    if ([scopeBarView viewWithTag:kTagSearchField]) {
        return YES;
    }
    
    NSButton *button = nil;
    for (__kindof NSView *subView in scopeBarView.subviews) {
        if ([[subView className] isEqualToString:@"NSButton"]) {
            button = subView;
            break;
        }
    }
    
    NSRect frame = button.frame;
    frame.origin.x -= button.frame.size.width + 205;
    frame.size.width = 200.0;
    frame.size.height -= 2;
    
    NSSearchField *searchField   = [[NSSearchField alloc] initWithFrame:frame];
    searchField.autoresizingMask = NSViewMinXMargin;
    searchField.font             = [NSFont systemFontOfSize:11.0];
    //searchField.delegate         = self;
    searchField.consoleTextView  = (NSTextView *) consoleTextView;
    searchField.tag              = kTagSearchField;
    [searchField.cell setPlaceholderString:@"Regular Expression"];
    [scopeBarView addSubview:searchField];
    
    return YES;
}

#pragma mark - Notifications

- (void)searchFieldDidEndEditing:(NSNotification *)notification {
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

    NSTextView *consoleTextView      = searchField.consoleTextView;
    MCLogIDEConsoleArea *consoleArea = searchField.consoleArea;

// get rid of the annoying 'undeclared selector' warning
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
    if ([consoleTextView respondsToSelector:@selector(clearConsoleItems)]) {
        [consoleTextView performSelector:@selector(clearConsoleItems) withObject:nil];
    }

    NSString *cachedKey = hash(consoleArea);
    if (cachedKey) {
        NSArray *sortedItems = [[self.class consoleItemsMap][cachedKey] orderedItems];

        if ([consoleArea respondsToSelector:@selector(_appendItems:)]) {
            [consoleArea performSelector:@selector(_appendItems:) withObject:sortedItems];
        }

        [[self.class filterPatternsMap] removeObjectForKey:cachedKey];
    }
#pragma clang diagnostic pop
}

- (void)activate:(NSNotification *)notification {
    [self addCustomViews];
}

@end


NS_ASSUME_NONNULL_END
