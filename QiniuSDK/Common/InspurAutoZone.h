//
//  QNAutoZone.h
//  QiniuSDK
//
//  Created by yangsen on 2020/4/16.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "InspurZone.h"

NS_ASSUME_NONNULL_BEGIN

@interface InspurAutoZone : InspurZone

+ (instancetype)zoneWithUcHosts:(NSArray *)ucHosts;

+ (void)clearCache;

@end

NS_ASSUME_NONNULL_END
