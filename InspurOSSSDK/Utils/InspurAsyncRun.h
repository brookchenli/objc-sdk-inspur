//
//  InspurAsyncRun.h
//  InspurOSSSDK
//
//  Created by Brook on 14/10/17.
//  Copyright (c) 2014年 Inspur. All rights reserved.
//

#import <Foundation/Foundation.h>

#define kInspurBackgroundQueue dispatch_get_global_queue(0, 0)
#define kInspurMainQueue dispatch_get_main_queue()

typedef void (^QNRun)(void);

void InspurAsyncRun(QNRun run);

void InspurAsyncRunInMain(QNRun run);

void InspurAsyncRunAfter(NSTimeInterval time, dispatch_queue_t queue, QNRun run);
