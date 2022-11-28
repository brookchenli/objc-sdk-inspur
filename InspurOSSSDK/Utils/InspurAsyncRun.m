//
//  InspurAsyncRun.m
//  InspurOSSSDK
//
//  Created by Brook on 14/10/17.
//  Copyright (c) 2014年 Inspur. All rights reserved.
//

#import "InspurAsyncRun.h"
#import <Foundation/Foundation.h>

void InspurAsyncRun(InspurRun run) {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
        run();
    });
}

void InspurAsyncRunInMain(InspurRun run) {
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        run();
    });
}

void InspurAsyncRunAfter(NSTimeInterval time, dispatch_queue_t queue, InspurRun run) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(time * NSEC_PER_SEC)), queue, ^{
        run();
    });
}
