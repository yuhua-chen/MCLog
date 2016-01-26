//
//  MCIDEConsoleItem.h
//  MCLog
//
//  Created by Alex Lee on 1/6/16.
//  Copyright © 2016 Yuhua Chen. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, MCLogLevel) {
    MCLogLevelVerbose = 0x1000,
    MCLogLevelInfo,
    MCLogLevelWarn,
    MCLogLevelError
};


@interface NSObject (MCIDEConsoleItem)

@property(nonatomic) NSUInteger          logLevel;
//@property(nonatomic) NSAttributedString *attributeString;

@end



@interface MCIDEConsoleItem : NSObject

- (id)initWithAdaptorType:(id)arg1 content:(id)arg2 kind:(int)arg3;

@end
