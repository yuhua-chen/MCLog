//
//  MCLog.m
//  MCLog
//
//  Created by Michael Chen on 2014/8/1.
//  Copyright (c) 2014年 Yuhua Chen. All rights reserved.
//

#include <execinfo.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import "HHTimer.h"
#import "MCDVTTextStorage.h"
#import "MCLog.h"
#import "MCOrderedMap.h"
#import "MCXcodeHeaders.h"
#import "NSView+MCLog.h"
#import "MCIDEConsoleItem.h"
#import "NSSearchField+MCLog.h"
#import "Utils.h"
#import "MethodSwizzle.h"
#import "MCLogIDEConsoleArea.h"

NS_ASSUME_NONNULL_BEGIN


#pragma mark - method swizzle


@implementation MCLog

+ (void)load {
    if (getenv(MCLOG_FLAG) && !strcmp(getenv(MCLOG_FLAG), "YES")) {
        // alreay installed plugin
        return;
    }
    setenv(MCLOG_FLAG, "YES", 0);
}

+ (void)pluginDidLoad:(NSBundle *)bundle {
    static id sharedPlugin = nil;
    static dispatch_once_t onceToken;

    NSString *currentApplicationName = [[NSBundle mainBundle] infoDictionary][@"CFBundleName"];
    if ([currentApplicationName isEqual:@"Xcode"]) {
        dispatch_once(&onceToken, ^{
            sharedPlugin = [[self alloc] init];
        });
    }
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
    for (NSWindow *window in [NSApp windows]) {
        NSView *contentView = [window contentView];
        NSTextView *consoleTextView = [contentView descendantViewByClassName:@"IDEConsoleTextView"];

        if (!consoleTextView) {
            continue;
        }

        DVTTextStorage *textStorage = [consoleTextView valueForKey:@"textStorage"];
        if ([textStorage respondsToSelector:@selector(setConsoleStorage:)]) {
            [textStorage setConsoleStorage:YES];
        }

        NSView *scopeBarView = nil;
        NSView *parent = consoleTextView.superview;
        while (!scopeBarView) {
            if (!parent) break;
            scopeBarView = [parent descendantViewByClassName:@"DVTScopeBarView"];
            parent = parent.superview;
        }

        if (!scopeBarView) {
            continue;
        }

        [self addLogLevelButtonItemsAt:scopeBarView defaultLogLevel:[[consoleTextView valueForKey:@"logMode"] intValue]];
        [self addLogFilterPatternTextFieldAt:scopeBarView associateWith:consoleTextView];
    }

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
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(searchFieldDidEndEditing:)
                                                 name:NSControlTextDidEndEditingNotification
                                               object:nil];
    
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
    NSString *cachedKey = hash(consoleArea);
    if (cachedKey == nil) {
        return;
    }
    
    NSString *lastFilterText = nil;
    id filterPattern = [self.class filterPatternsMap][cachedKey];
    if ([filterPattern isKindOfClass:[NSRegularExpression class]]) {
        lastFilterText = ((NSRegularExpression *) filterPattern).pattern;
    }
    lastFilterText = lastFilterText.length == 0 ? @"" : lastFilterText;
    
    if ([searchField.stringValue isEqualToString:lastFilterText]) {
        return;
    }

// get rid of the annoying 'undeclared selector' warning
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
    if ([consoleTextView respondsToSelector:@selector(clearConsoleItems)]) {
        [consoleTextView performSelector:@selector(clearConsoleItems) withObject:nil];
    }

    static SEL selector = nil;
    static BOOL canResponse = NO;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        selector = @selector(_appendItems:);
        canResponse = [consoleArea respondsToSelector:selector];
    });
    if (canResponse) {
        NSArray *sortedItems = [[self.class consoleItemsMap][cachedKey] orderedItems];
        objc_msgSend(consoleArea, selector, sortedItems);
    }
#pragma clang diagnostic pop
}


- (void)activate:(NSNotification *)notification {
    [self addCustomViews];
}

@end


NS_ASSUME_NONNULL_END
