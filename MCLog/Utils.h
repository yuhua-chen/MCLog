//
//  Utils.h
//  MCLog
//
//  Created by Alex Lee on 1/6/16.
//  Copyright © 2016 Yuhua Chen. All rights reserved.
//

#import <Foundation/Foundation.h>

NSRegularExpression * logItemPrefixPattern();
NSSearchField *getSearchField(id consoleArea);

NSArray<NSString *> *backtraceStack();

NSString *hash(id obj);
