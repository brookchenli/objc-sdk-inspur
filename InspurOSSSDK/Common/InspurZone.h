//
//  InspurZone.h
//  InspurOSSSDK
//
//  Created by Brook on 2020/4/16.
//  Copyright © 2020 Inspur. All rights reserved.
//

#import "InspurApiType.h"

NS_ASSUME_NONNULL_BEGIN

@class InspurResponseInfo, InspurUpToken, InspurZonesInfo, InspurUploadRegionRequestMetrics;

typedef void (^InspurPrequeryReturn)(int code, InspurResponseInfo * _Nullable httpResponseInfo, InspurUploadRegionRequestMetrics * _Nullable metrics);

@interface InspurZone : NSObject

/// 根据token查询相关 Zone 信息【内部使用】
/// @param token token 信息
/// @param ret 查询回调
- (void)preQuery:(InspurUpToken * _Nullable)token
              on:(InspurPrequeryReturn _Nullable)ret;

/// 根据token查询相关 Zone 信息【内部使用】
/// @param token token 信息
/// @param actionType action 类型
/// @param ret 查询回调
- (void)preQuery:(InspurUpToken * _Nullable)token
      actionType:(InspurActionType)actionType
              on:(InspurPrequeryReturn _Nullable)ret;

/// 根据token获取ZonesInfo 【内部使用】
/// @param token token信息
- (InspurZonesInfo *)getZonesInfoWithToken:(InspurUpToken * _Nullable)token;

/// 获取ZonesInfo 【内部使用】
/// @param token token 信息
/// @param actionType action 类型
- (InspurZonesInfo *)getZonesInfoWithToken:(InspurUpToken * _Nullable)token actionType:(InspurActionType)actionType;

@end

NS_ASSUME_NONNULL_END
