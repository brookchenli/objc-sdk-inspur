//
//  InspurFixZone.h
//  InspurOSSSDK
//
//  Created by Brook on 2020/4/16.
//  Copyright © 2020 Inspur. All rights reserved.
//

#import "InspurZone.h"

NS_ASSUME_NONNULL_BEGIN

@interface InspurFixedZone : InspurZone

/**
 *    zone 0 华东
 *
 *    @return 实例
 */
+ (instancetype)zone0;

+ (instancetype)north3;

/**
 *    zoneCnEast2 华东-浙江2
 *
 *    @return 实例
 */
+ (instancetype)zoneCnEast2;

/**
 *    zone 1 华北
 *
 *    @return 实例
 */
+ (instancetype)zone1;

/**
 *    zone 2 华南
 *
 *    @return 实例
 */
+ (instancetype)zone2;

/**
 *    zoneNorthEast1 亚太-首尔
 *
 *    @return 实例
 */
+ (instancetype)zoneApNorthEast1;

/**
 *    zone Na0 北美
 *
 *    @return 实例
 */
+ (instancetype)zoneNa0;

/**
 *    zone As0 新加坡
 *
 *    @return 实例
 */
+ (instancetype)zoneAs0;

/**
 *    Zone初始化方法
 *
 *    @param upList     默认上传服务器地址列表
 *    @return Zone实例
 */
- (instancetype)initWithUpDomainList:(NSArray<NSString *> *)upList;

/**
 *    Zone初始化方法
 *
 *    @param upList     默认上传服务器地址列表
 *
 *    @return Zone实例
 */
+ (instancetype)createWithHost:(NSArray<NSString *> *)upList;

/**
 *   获取本地所有固定zone信息
 */
+ (InspurFixedZone *)localsZoneInfo;

@end

NS_ASSUME_NONNULL_END
