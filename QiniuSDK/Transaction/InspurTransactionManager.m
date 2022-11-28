//
//  QNTransactionManager.m
//  QiniuSDK
//
//  Created by yangsen on 2020/4/1.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "InspurDefine.h"
#import "InspurTransactionManager.h"

//MARK: -- 事务对象
typedef NS_ENUM(NSInteger, QNTransactionType){
    QNTransactionTypeNormal, // 普通类型事务，事务体仅会执行一次
    QNTransactionTypeTime, // 定时事务，事务体会定时执行
};

@interface InspurTransaction()
// 事务类型
@property(nonatomic, assign)QNTransactionType type;
// 定时任务执行时间间隔
@property(nonatomic, assign)NSInteger interval;
// 事务延后时间 单位：秒
@property(nonatomic, assign)NSInteger after;
// 事务执行时间 与事务管理者定时器时间相关联
@property(nonatomic, assign)double createTime;
// 执行次数
@property(nonatomic, assign)long executedCount;
// 下次执行时的时间戳
@property(nonatomic, assign)double nextExecutionTime;

// 事务名称
@property(nonatomic,  copy)NSString *name;
// 事务执行体
@property(nonatomic,  copy)void(^action)(void);
// 下一个需要处理的事务
@property(nonatomic, strong, nullable)InspurTransaction *nextTransaction;

@end
@implementation InspurTransaction

+ (instancetype)transaction:(NSString *)name
                      after:(NSInteger)after
                     action:(void (^)(void))action{
    InspurTransaction *transaction = [[InspurTransaction alloc] init];
    transaction.type = QNTransactionTypeNormal;
    transaction.after = after;
    transaction.name = name;
    transaction.action = action;
    transaction.executedCount = 0;
    transaction.createTime = [[NSDate date] timeIntervalSince1970];
    transaction.nextExecutionTime = transaction.createTime + after;
    return transaction;
}

+ (instancetype)timeTransaction:(NSString *)name
                          after:(NSInteger)after
                       interval:(NSInteger)interval
                         action:(void (^)(void))action{
    InspurTransaction *transaction = [[InspurTransaction alloc] init];
    transaction.type = QNTransactionTypeTime;
    transaction.after = after;
    transaction.name = name;
    transaction.interval = interval;
    transaction.action = action;
    transaction.executedCount = 0;
    transaction.createTime = [[NSDate date] timeIntervalSince1970];
    transaction.nextExecutionTime = transaction.createTime + after;
    return transaction;
}

- (BOOL)shouldAction {
    double currentTime = [[NSDate date] timeIntervalSince1970];
    if (self.type == QNTransactionTypeNormal) {
        return self.executedCount < 1 && currentTime >= self.nextExecutionTime;
    } else if (self.type == QNTransactionTypeTime) {
        return currentTime >= self.nextExecutionTime;
    } else {
        return NO;
    }
}

- (BOOL)maybeCompleted {
    if (self.type == QNTransactionTypeNormal) {
        return self.executedCount > 0;
    } else if (self.type == QNTransactionTypeTime) {
        return false;
    } else {
        return false;
    }
}

- (void)handleAction {
    if (![self shouldAction]) {
        return;
    }
    if (self.action) {
        _isExecuting = YES;
        self.executedCount += 1;
        self.nextExecutionTime = [[NSDate date] timeIntervalSince1970] + self.interval;
        self.action();
        _isExecuting = NO;
    }
}

@end


//MARK: -- 事务链表
@interface InspurTransactionList : NSObject

@property(nonatomic, strong)InspurTransaction *header;

@end
@implementation InspurTransactionList

- (BOOL)isEmpty{
    if (self.header == nil) {
        return YES;
    } else {
        return NO;
    }
}

- (NSArray <InspurTransaction *> *)transactionsForName:(NSString *)name{
    NSMutableArray *transactions = [NSMutableArray array];
    [self enumerate:^(InspurTransaction *transaction, BOOL * _Nonnull stop) {
        if ((name == nil && transaction.name == nil)
            || (name != nil && transaction.name != nil && [transaction.name isEqualToString:name])) {
            [transactions addObject:transaction];
        }
    }];
    return [transactions copy];
}

- (void)enumerate:(void(^)(InspurTransaction *transaction, BOOL * _Nonnull stop))handler {
    if (!handler) {
        return;
    }
    BOOL isStop = NO;
    InspurTransaction *transaction = self.header;
    while (transaction && !isStop) {
        handler(transaction, &isStop);
        transaction = transaction.nextTransaction;
    }
}

- (void)add:(InspurTransaction *)transaction{
    
    @synchronized (self) {
        InspurTransaction *transactionP = self.header;
        while (transactionP.nextTransaction) {
            transactionP = transactionP.nextTransaction;
        }
        
        if (transactionP) {
            transactionP.nextTransaction = transaction;
        } else {
            self.header = transaction;
        }
    }
}

- (void)remove:(InspurTransaction *)transaction{
    
    @synchronized (self) {
        InspurTransaction *transactionP = self.header;
        InspurTransaction *transactionLast = nil;
        while (transactionP) {
            if (transactionP == transaction) {
                if (transactionLast) {
                    transactionLast.nextTransaction = transactionP.nextTransaction;
                } else {
                    self.header = transactionP.nextTransaction;
                }
                break;
            }
            transactionLast = transactionP;
            transactionP = transactionP.nextTransaction;
        }
    }
}

- (BOOL)has:(InspurTransaction *)transaction{
    @synchronized (self) {
        __block BOOL has = NO;
        [self enumerate:^(InspurTransaction *transactionP, BOOL * _Nonnull stop) {
            if (transaction == transactionP) {
                has = YES;
                *stop = YES;
            }
        }];
        return has;
    }
}

- (void)removeAll{
    @synchronized (self) {
        self.header = nil;
    }
}

@end


//MARK: -- 事务管理者
@interface InspurTransactionManager()
// 事务处理线程
@property(nonatomic, strong)NSThread *thread;
// 事务链表
@property(nonatomic, strong)InspurTransactionList *transactionList;

// 事务定时器
@property(nonatomic, strong)NSTimer *timer;

@end
@implementation InspurTransactionManager

+ (instancetype)shared{
    static InspurTransactionManager *manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[InspurTransactionManager alloc] init];
    });
    return manager;
}
- (instancetype)init{
    if (self = [super init]) {
        _transactionList = [[InspurTransactionList alloc] init];
    }
    return self;
}

- (NSArray <InspurTransaction *> *)transactionsForName:(NSString *)name{
    return [self.transactionList transactionsForName:name];
}

- (BOOL)existTransactionsForName:(NSString *)name{
    NSArray *transactionList = [self transactionsForName:name];
    if (transactionList && transactionList.count > 0) {
        return YES;
    } else {
        return NO;
    }
}

- (void)addTransaction:(InspurTransaction *)transaction{
    if (transaction == nil) {
        return;
    }
    [self.transactionList add:transaction];
    [self createThread];
}

- (void)removeTransaction:(InspurTransaction *)transaction{
    if (transaction == nil) {
        return;
    }
    [self.transactionList remove:transaction];
}

- (void)performTransaction:(InspurTransaction *)transaction{
    if (transaction == nil) {
        return;
    }
    @synchronized (self) {
        if (![self.transactionList has:transaction]) {
            [self.transactionList add:transaction];
        }
        transaction.createTime = [[NSDate date] timeIntervalSince1970] - transaction.interval;
    }
}

/// 销毁资源
- (void)destroyResource{

    @synchronized (self) {
        [self invalidateTimer];
        [self.thread cancel];
        self.thread = nil;
        [self.transactionList removeAll];
    }
}


//MARK: -- handle transaction action
- (void)handleAllTransaction{
    
    [self.transactionList enumerate:^(InspurTransaction *transaction, BOOL * _Nonnull stop) {
        [self handleTransaction:transaction];
        if ([transaction maybeCompleted]) {
            [self removeTransaction:transaction];
        }
    }];
}

- (void)handleTransaction:(InspurTransaction *)transaction{
    [transaction handleAction];
}

//MARK: -- thread
- (void)createThread{
    @synchronized (self) {
        if (self.thread == nil) {
            kInspurWeakSelf;
            self.thread = [[NSThread alloc] initWithTarget:weak_self
                                                  selector:@selector(threadAction)
                                                     object:nil];
            self.thread.name = @"com.qiniu.transaction";
            [self.thread start];
        }
    }
}

- (void)threadAction{

    @autoreleasepool {
        if (self.timer == nil) {
            [self createTimer];
        }
        NSThread *thread = [NSThread currentThread];
        while (thread && !thread.isCancelled) {
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                     beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
        }
    }
}

//MARK: -- timer
- (void)createTimer{
    kInspurWeakSelf;
    NSTimer *timer = [NSTimer timerWithTimeInterval:1
                                             target:weak_self
                                           selector:@selector(timerAction)
                                           userInfo:nil
                                            repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:timer
                                 forMode:NSDefaultRunLoopMode];
    
    [self timerAction];
    _timer = timer;
}

- (void)invalidateTimer{
    [self.timer invalidate];
    self.timer = nil;
}

- (void)timerAction{
    [self handleAllTransaction];
}

@end
