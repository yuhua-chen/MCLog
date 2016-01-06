//
//  Utils.m
//  MCLog
//
//  Created by Alex Lee on 1/6/16.
//  Copyright © 2016 Yuhua Chen. All rights reserved.
//

#import "Utils.h"
#include <execinfo.h>

NSRegularExpression * logItemPrefixPattern() {
    static NSRegularExpression *pattern = nil;
    if (pattern == nil) {
        NSError *error = nil;
        pattern = [NSRegularExpression
                   regularExpressionWithPattern:@"\\d{4}-\\d{2}-\\d{2}\\s\\d{2}:\\d{2}:\\d{2}[\\.:]\\d{3}"
                   @"\\s+.+\\[[\\da-fA-F]+:[\\da-fA-F]+\\]\\s+"
                   options:NSRegularExpressionCaseInsensitive
                   error:&error];
        if (!pattern) {
            MCLogger(@"%@", error);
        }
    }
    return pattern;
}

NSSearchField *getSearchField(id consoleArea) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
    if (![consoleArea respondsToSelector:@selector(scopeBarView)]) {
        return nil;
    }
    
    NSView *scopeBarView = [consoleArea performSelector:@selector(scopeBarView) withObject:nil];
    return [scopeBarView viewWithTag:kTagSearchField];
#pragma clang diagnositc pop
}


NSArray<NSString *> *backtraceStack() {
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


NSString *hash(id obj) {
    if (!obj) {
        return nil;
    }
    
    return [NSString stringWithFormat:@"%lx", (long)obj];
}
