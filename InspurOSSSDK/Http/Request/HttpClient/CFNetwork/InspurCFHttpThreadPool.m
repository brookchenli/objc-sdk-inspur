//
//  InspurCFHttpThreadPool.m
//  Qiniu
//
//  Created by Brook on 2021/10/13.
//

#import "InspurCFHttpThreadPool.h"
#import "InspurTransactionManager.h"

@interface InspurCFHttpThread()
@property(nonatomic, assign)BOOL isCompleted;
@property(nonatomic, assign)NSInteger operationCount;
@property(nonatomic, strong)NSDate *deadline;
@end
@implementation InspurCFHttpThread
+ (instancetype)thread {
    return [[InspurCFHttpThread alloc] init];;
}

- (instancetype)init {
    if (self = [super init]) {
        self.isCompleted = NO;
        self.operationCount = 0;
    }
    return self;
}

- (void)main {
    @autoreleasepool {
        [super main];
        
        while (!self.isCompleted) {
            [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1]];
        }
    }
}

- (void)cancel {
    self.isCompleted = YES;
}

@end

@interface InspurCFHttpThreadPool()
// 单位：秒
@property(nonatomic, assign)NSInteger threadLiveTime;
@property(nonatomic, assign)NSInteger maxOperationPerThread;
@property(nonatomic, strong)NSMutableArray *pool;
@end
@implementation InspurCFHttpThreadPool

+ (instancetype)shared {
    static InspurCFHttpThreadPool *pool = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        pool = [[InspurCFHttpThreadPool alloc] init];
        pool.threadLiveTime = 60;
        pool.maxOperationPerThread = 6;
        pool.pool = [NSMutableArray array];
        [pool addThreadLiveChecker];
    });
    return pool;
}

- (void)addThreadLiveChecker {
    InspurTransaction *transaction = [InspurTransaction timeTransaction:@"CFHttpThreadPool" after:0 interval:1 action:^{
        [self checkThreadLive];
    }];
    [kInspurTransactionManager addTransaction:transaction];
}

- (void)checkThreadLive {
    @synchronized (self) {
        NSArray *pool = [self.pool copy];
        for (InspurCFHttpThread *thread in pool) {
            if (thread.operationCount < 1 && thread.deadline && [thread.deadline timeIntervalSinceNow] < 0) {
                [self.pool removeObject:thread];
                [thread cancel];
            }
        }
    }
}

- (InspurCFHttpThread *)getOneThread {
    InspurCFHttpThread *thread = nil;
    @synchronized (self) {
        for (InspurCFHttpThread *t in self.pool) {
            if (t.operationCount < self.maxOperationPerThread) {
                thread = t;
                break;
            }
        }
        if (thread == nil) {
            thread = [InspurCFHttpThread thread];
            thread.name = [NSString stringWithFormat:@"com.qiniu.cfclient.%lu", (unsigned long)self.pool.count];
            [thread start];
            [self.pool addObject:thread];
        }
        thread.deadline = nil;
    }
    return thread;
}

- (void)addOperationCountOfThread:(InspurCFHttpThread *)thread {
    if (thread == nil) {
        return;
    }
    @synchronized (self) {
        thread.operationCount += 1;
        thread.deadline = nil;
    }
}

- (void)subtractOperationCountOfThread:(InspurCFHttpThread *)thread {
    if (thread == nil) {
        return;
    }
    @synchronized (self) {
        thread.operationCount -= 1;
        if (thread.operationCount < 1) {
            thread.deadline = [NSDate dateWithTimeIntervalSinceNow:self.threadLiveTime];
        }
    }
}

@end
