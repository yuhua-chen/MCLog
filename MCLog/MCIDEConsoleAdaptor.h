//
//  MCIDEConsoleAdaptor.h
//  MCLog
//
//  Created by Alex Lee on 1/6/16.
//  Copyright © 2016 Yuhua Chen. All rights reserved.
//

#import <Foundation/Foundation.h>

@class HHTimer;
@interface MCIDEConsoleAdaptor: NSObject

- (void)outputForStandardOutput:(id)arg1 isPrompt:(BOOL)arg2 isOutputRequestedByUser:(BOOL)arg3;

@end


@interface NSObject (MCIDEConsoleAdaptor)

@property(nonatomic, strong) HHTimer      *timer;
@property(nonatomic, copy)   NSDictionary *unprocessedOutputInfo;

- (void)mc_outputUnprocessedBuffer;

@end
