//
//  MCLog.m
//  MCLog
//
//  Created by Michael Chen on 2014/8/1.
//  Copyright (c) 2014年 Yuhua Chen. All rights reserved.
//

#import "MCLog.h"
#import <objc/runtime.h>

#define MCLOG_FLAG "MCLOG_FLAG"
#define kTagSearchField	99

static NSMutableDictionary *originConsoleItemsMap;
static MCLogIDEConsoleArea *consoleArea = nil;
static IMP _clearText = nil;

@interface MCLog ()<NSTextFieldDelegate>
{
	NSMutableDictionary *workspace;
}
@end

@implementation MCLog

+ (void)load
{
	NSLog(@"%s, env: %s", __PRETTY_FUNCTION__, getenv(MCLOG_FLAG));
	
//	if (getenv(MCLOG_FLAG) && !strcmp(getenv(MCLOG_FLAG), "YES")) {
//		// alreay installed plugin
//		return;
//    }
	
	replaceShouldAppendItemMethod();
	replaceClearTextMethod();
	originConsoleItemsMap = [NSMutableDictionary dictionary];
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
		workspace = [NSMutableDictionary dictionary];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(activate:) name:@"IDEIndexWillIndexWorkspaceNotification" object:nil];
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
	for (NSView *subView in scopeBarView.subviews) {
		if ([[subView className] isEqualToString:@"NSButton"]) {
			button = (NSButton *)subView;
			break;
		}
	}
	
	if (!button) {
		return NO;
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

#pragma mark - Notifications

- (void)searchFieldDidEndEditing:(NSNotification *)notification
{
	if (![[notification object] isMemberOfClass:[NSTextField class]]) {
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
	
	NSMutableDictionary *originConsoleItems = [originConsoleItemsMap objectForKey:hash(consoleArea)];
	NSArray *sortedItems = [[originConsoleItems allValues] sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
		NSTimeInterval a = [obj1 timestamp];
		NSTimeInterval b = [obj2 timestamp];
		if (a > b) {
			return NSOrderedDescending;
		}
		
		if(a < b) {
			return NSOrderedAscending;
		}
		
		return NSOrderedSame;
	}];

	if ([consoleArea respondsToSelector:@selector(_appendItems:)]) {
		[consoleArea performSelector:@selector(_appendItems:) withObject:sortedItems];
	}
	#pragma clang diagnostic pop
}

- (void)activate:(NSNotification *)notification {
	
	id IDEIndex = [notification object];
	BOOL isAdded = [[workspace objectForKey:hash(IDEIndex)] boolValue];
	if (isAdded) {
		return;
	}
	if ([self addCustomViews]) {
		[workspace setObject:@(YES) forKey:hash(IDEIndex)];
	}
}

@end

#pragma mark - NSSearchField (MCLog)

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

#pragma mark - MCLogIDEConsoleArea

@implementation MCLogIDEConsoleArea

- (BOOL)_shouldAppendItem:(id)obj;
{
	NSSearchField *searchField = getSearchField(self);
	if (!searchField) {
		return YES;
	}
	
	if (!searchField.consoleArea) {
		searchField.consoleArea = self;
	}
	
	NSMutableDictionary *originConsoleItems = [originConsoleItemsMap objectForKey:hash(self)];
	if (!originConsoleItems) {
		originConsoleItems = [NSMutableDictionary dictionary];
	}
	
	// store all console items.
	[originConsoleItems setObject:obj forKey:@([obj timestamp])];
	[originConsoleItemsMap setObject:originConsoleItems forKey:hash(self)];
	
	if (![searchField.stringValue length]) {
		return YES;
	}
	
	// test with the regular expression
	NSString *content = [obj content];
	NSRange range = NSMakeRange(0, content.length);
	NSError *error;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:searchField.stringValue
																		   options:(NSRegularExpressionCaseInsensitive|NSRegularExpressionDotMatchesLineSeparators)
																			 error:&error];
    if (regex == nil) {
		// display all if with regex is error
        NSLog(@"%s, error:%@", __PRETTY_FUNCTION__, error);
        return YES;
    }
	
    NSArray *matches = [regex matchesInString:content options:0 range:range];	
	if ([matches count]) {
		return YES;
	}

	return NO;
}

- (void)_clearText
{
	_clearText(self, _cmd);
	[originConsoleItemsMap removeObjectForKey:hash(self)];
}
@end

#pragma mark -

void replaceShouldAppendItemMethod()
{
	Class IDEConsoleArea = NSClassFromString(@"IDEConsoleArea");
    Method originalMethod = class_getInstanceMethod([IDEConsoleArea class], @selector(_shouldAppendItem:));
	
	IMP newImpl = class_getMethodImplementation([MCLogIDEConsoleArea class], @selector(_shouldAppendItem:));
	method_setImplementation(originalMethod, newImpl);
}

void replaceClearTextMethod()
{
	Class IDEConsoleArea = NSClassFromString(@"IDEConsoleArea");
	Method originalMethod = class_getInstanceMethod([IDEConsoleArea class], @selector(_clearText));
	_clearText = method_getImplementation(originalMethod);
	
	IMP newImpl = class_getMethodImplementation([MCLogIDEConsoleArea class], @selector(_clearText));
	method_setImplementation(originalMethod, newImpl);
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