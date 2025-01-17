//
//  InspurInetAddress.h
//  InspurOSSSDK
//
//  Created by Brook on 2020/7/27.
//  Copyright © 2020 Inspur. All rights reserved.
//

#import "InspurDns.h"

NS_ASSUME_NONNULL_BEGIN

@interface InspurInetAddress : NSObject <InspurIDnsNetworkAddress>

@property(nonatomic,  copy)NSString *hostValue;
@property(nonatomic,  copy)NSString *ipValue;
@property(nonatomic, strong)NSNumber *ttlValue;
@property(nonatomic, strong)NSNumber *timestampValue;
@property(nonatomic,   copy)NSString *sourceValue;


/// 构造方法 addressData为json
/// @param addressInfo 地址信息，类型可能为String / Dictionary / Data / 遵循 QNInetAddressDelegate的实例
+ (instancetype)inetAddress:(id)addressInfo;

/// 是否有效，根据时间戳判断
- (BOOL)isValid;

/// 对象转json
- (NSString *)toJsonInfo;

/// 对象转字典
- (NSDictionary *)toDictionary;

@end

NS_ASSUME_NONNULL_END
