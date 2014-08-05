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

static NSSearchField *searchFiled = nil;
static NSMutableDictionary *originConsoleItems;
static MCLogIDEConsoleArea *consoleArea = nil;

@interface MCLog ()<NSTextFieldDelegate>
{
	NSView *scopeBarView;
	NSView *consoleTextView;
}
@end

@implementation MCLog

+ (void)load
{
	NSLog(@"%s, env: %s", __PRETTY_FUNCTION__, getenv(MCLOG_FLAG));
	
	if (getenv(MCLOG_FLAG) && !strcmp(getenv(MCLOG_FLAG), "YES")) {
		// alreay installed plugin
		return;
    }
	
	replaceShouldAppendItemMethod();
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
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(activate:) name:NSWindowDidUpdateNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(clearConsoleItems:) name:@"IDEBuildOperationDidStopNotification" object:nil];
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

- (BOOL)initViews
{
	NSView *contentView = [[NSApp mainWindow] contentView];
	consoleTextView = [self getViewByClassName:@"IDEConsoleTextView" andContainerView:contentView];
	
	contentView = [self getParantViewByClassName:@"DVTControllerContentView" andView:consoleTextView];
	scopeBarView = [self getViewByClassName:@"DVTScopeBarView" andContainerView:contentView];
	return scopeBarView && consoleTextView;
}

- (BOOL)addCustomViews
{
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
	
	searchFiled = [[NSSearchField alloc] initWithFrame:frame];
	searchFiled.autoresizingMask = NSViewMinXMargin;
	searchFiled.font = [NSFont systemFontOfSize:11.0];
	searchFiled.delegate = self;
	[searchFiled.cell setPlaceholderString:@"Regular Expression"];
	[scopeBarView addSubview:searchFiled];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(searchFieldDidEndEditing:) name:NSControlTextDidEndEditingNotification object:nil];
	
	return YES;
}

#pragma mark - Notifications

- (void)searchFieldDidEndEditing:(NSNotification *)notification
{
	if ([notification object]!=searchFiled) {
		return;
	}
	
	// get rid of the annoying 'undeclared selector' warning
	#pragma clang diagnostic push
	#pragma clang diagnostic ignored "-Wundeclared-selector"
	if ([consoleTextView respondsToSelector:@selector(clearConsoleItems)]) {
		[consoleTextView performSelector:@selector(clearConsoleItems) withObject:nil];
	}

	if ([consoleArea respondsToSelector:@selector(_appendItems:)]) {
		[consoleArea performSelector:@selector(_appendItems:) withObject:[originConsoleItems allValues]];
	}
	#pragma clang diagnostic pop
}

- (void)activate:(NSNotification *)notification {
	
	if (![self initViews]) {
		return;
	}
	
	if ([self addCustomViews]) {
		[[NSNotificationCenter defaultCenter] removeObserver:self name:NSWindowDidUpdateNotification object:nil];
	}
}

- (void)clearConsoleItems:(NSNotification *)notification
{
	// clear up the old items when rebuild
	originConsoleItems = [NSMutableDictionary dictionary];
}

@end

@implementation MCLogIDEConsoleArea

- (BOOL)_shouldAppendItem:(id)obj;
{
	if (!consoleArea) {
		consoleArea = self;	// get current console area
		originConsoleItems = [NSMutableDictionary dictionary];
	}
	
	// store all console items.
	[originConsoleItems setObject:obj forKey:@([obj timestamp])];
	
	if (![searchFiled.stringValue length]) {
		return YES;
	}
	
	// test the regular expression
	NSString *content = [obj content];
	NSRange range = NSMakeRange(0, content.length);
	NSError *error;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:searchFiled.stringValue
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

@end

void replaceShouldAppendItemMethod()
{
	Class IDEConsoleArea = NSClassFromString(@"IDEConsoleArea");
    Method originalMethod = class_getInstanceMethod([IDEConsoleArea class], @selector(_shouldAppendItem:));
	
	IMP newImpl = class_getMethodImplementation([MCLogIDEConsoleArea class], @selector(_shouldAppendItem:));
	method_setImplementation(originalMethod, newImpl);
}
