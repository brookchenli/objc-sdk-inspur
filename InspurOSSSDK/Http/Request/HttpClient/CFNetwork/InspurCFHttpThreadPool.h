//
//  InspurCFHttpThreadPool.h
//  Qiniu
//
//  Created by Brook on 2021/10/13.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface InspurCFHttpThread : NSThread

@property(nonatomic, assign, readonly)NSInteger operationCount;

@end


@interface InspurCFHttpThreadPool : NSObject

@property(nonatomic, assign, readonly)NSInteger maxOperationPerThread;

+ (instancetype)shared;

- (InspurCFHttpThread *)getOneThread;
- (void)addOperationCountOfThread:(InspurCFHttpThread *)thread;
- (void)subtractOperationCountOfThread:(InspurCFHttpThread *)thread;

@end

NS_ASSUME_NONNULL_END
