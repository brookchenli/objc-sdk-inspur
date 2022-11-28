//
//  QNSingleFlight.m
//  QiniuSDK
//
//  Created by Brook on 2021/1/4.
//  Copyright © 2021 Inspur. All rights reserved.
//

#import "InspurDefine.h"
#import "InspurSingleFlight.h"

@interface InspurSingleFlightTask : NSObject
@property(nonatomic,  copy)QNSingleFlightComplete complete;
@end
@implementation InspurSingleFlightTask
@end

@interface InspurSingleFlightCall : NSObject
@property(nonatomic, assign)BOOL isComplete;
@property(nonatomic, strong)NSMutableArray <InspurSingleFlightTask *> *tasks;
@property(nonatomic, strong)id value;
@property(nonatomic, strong)NSError *error;
@end
@implementation InspurSingleFlightCall
@end

@interface InspurSingleFlight()
@property(nonatomic, strong)NSMutableDictionary <NSString *, InspurSingleFlightCall *> *callInfo;
@end
@implementation InspurSingleFlight

- (void)perform:(NSString * _Nullable)key
         action:(QNSingleFlightAction _Nonnull)action
       complete:(QNSingleFlightComplete _Nullable)complete {
    if (!action) {
        return;
    }

    BOOL isFirstTask = false;
    BOOL shouldComplete = false;
    InspurSingleFlightCall *call = nil;
    @synchronized (self) {
        if (!self.callInfo) {
            self.callInfo = [NSMutableDictionary dictionary];
        }
        
        if (key) {
            call = self.callInfo[key];
        }
        
        if (!call) {
            call = [[InspurSingleFlightCall alloc] init];
            call.isComplete = false;
            call.tasks = [NSMutableArray array];
            if (key) {
                self.callInfo[key] = call;
            }
            isFirstTask = true;
        }
        
        @synchronized (call) {
            shouldComplete = call.isComplete;
            if (!shouldComplete) {
                InspurSingleFlightTask *task = [[InspurSingleFlightTask alloc] init];
                task.complete = complete;
                [call.tasks addObject:task];
            }
        }
    }
    
    if (shouldComplete) {
        if (complete) {
            complete(call.value, call.error);
        }
        return;
    }
    if (!isFirstTask) {
        return;
    }
    
    kInspurWeakSelf;
    kInspurWeakObj(call);
    action(^(id value, NSError *error){
        kInspurStrongSelf;
        kInspurStrongObj(call);
        
        NSArray *tasksP = nil;
        @synchronized (call) {
            if (call.isComplete) {
                return;
            }
            call.isComplete = true;
            call.value = value;
            call.error = error;
            tasksP = [call.tasks copy];
        }
        
        if (key) {
            @synchronized (self) {
                [self.callInfo removeObjectForKey:key];
            }
        }
        
        for (InspurSingleFlightTask *task in tasksP) {
            if (task.complete) {
                task.complete(value, error);
            }
        }
    });
}

@end
