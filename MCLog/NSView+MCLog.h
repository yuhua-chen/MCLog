//
//  NSView+MCLog.h
//  MCLog
//
//  Created by Alex Lee on 1/6/16.
//  Copyright © 2016 Yuhua Chen. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN
@interface NSView (MCLog)

- (nullable __kindof NSView *)descendantViewByClassName:(NSString *)className;

- (nullable __kindof NSView *)ancestralViewByClassName:(NSString *)className;
@end

NS_ASSUME_NONNULL_END
