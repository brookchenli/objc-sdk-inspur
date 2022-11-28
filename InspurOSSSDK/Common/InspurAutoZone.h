//
//  InspurAutoZone.h
//  InspurOSSSDK
//
//  Created by Brook on 2020/4/16.
//  Copyright © 2020 Inspur. All rights reserved.
//

#import "InspurZone.h"

NS_ASSUME_NONNULL_BEGIN

@interface InspurAutoZone : InspurZone

+ (instancetype)zoneWithUcHosts:(NSArray *)ucHosts;

+ (void)clearCache;

@end

NS_ASSUME_NONNULL_END
