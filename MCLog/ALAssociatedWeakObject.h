//
//  ALAssociatedWeakObject.h
//  MCLog
//
//  Created by Alex Lee on 1/9/16.
//  Copyright © 2016 Yuhua Chen. All rights reserved.
//

#import <Foundation/Foundation.h>


//@see: http://stackoverflow.com/questions/22809848/objective-c-runtime-run-code-at-deallocation-of-any-object/31560217#31560217


@interface NSObject (AssociatedWeakObject)

- (void)mc_runAtDealloc:(void(^)(void))block;

@end