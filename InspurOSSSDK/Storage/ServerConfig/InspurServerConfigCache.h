//
//  QNServerConfigCache.h
//  InspurOSSSDK
//
//  Created by Brook on 2021/8/30.
//  Copyright © 2021 Inspur. All rights reserved.
//

#import "InspurServerConfig.h"
#import "InspurServerUserConfig.h"

NS_ASSUME_NONNULL_BEGIN

@interface InspurServerConfigCache : NSObject

@property(nonatomic, strong)InspurServerConfig *config;
@property(nonatomic, strong)InspurServerUserConfig *userConfig;

- (InspurServerConfig *)getConfigFromDisk;
- (void)saveConfigToDisk:(InspurServerConfig *)config;

- (InspurServerUserConfig *)getUserConfigFromDisk;
- (void)saveUserConfigToDisk:(InspurServerUserConfig *)config;

- (void)removeConfigCache;

@end

NS_ASSUME_NONNULL_END
