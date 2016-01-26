//
//  MCIDEConsoleTextView.h
//  MCLog
//
//  Created by Alex Lee on 1/8/16.
//  Copyright © 2016 Yuhua Chen. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface  NSTextView (MCIDEConsoleTextView)

- (BOOL)mc_writeSelectionToPasteboard:(NSPasteboard *)pboard type:(NSString *)type;

@end
