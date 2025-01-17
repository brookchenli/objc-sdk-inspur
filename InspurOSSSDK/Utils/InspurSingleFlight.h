//
//  InspurSingleFlight.h
//  InspurOSSSDK
//
//  Created by Brook on 2021/1/4.
//  Copyright © 2021 Inspur. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void(^InspurSingleFlightComplete)(id _Nullable value, NSError * _Nullable error);
typedef void(^InspurSingleFlightAction)(InspurSingleFlightComplete _Nonnull complete);

@interface InspurSingleFlight : NSObject

/**
 * 异步 SingleFlight 执行函数
 * @param key actionHandler 对应的 key，同一时刻同一个 key 最多只有一个对应的 actionHandler 在执行
 * @param actionHandler 执行函数，注意：actionHandler 有且只能回调一次
 * @param completeHandler  single flight 执行 actionHandler 后的完成回调
 */
- (void)perform:(NSString * _Nullable)key
         action:(InspurSingleFlightAction _Nonnull)action
       complete:(InspurSingleFlightComplete _Nullable)complete;

@end

NS_ASSUME_NONNULL_END
