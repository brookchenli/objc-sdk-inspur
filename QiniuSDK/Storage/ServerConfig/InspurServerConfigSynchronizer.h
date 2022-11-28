//
//  QNServerConfigSynchronizer.h
//  QiniuSDK
//
//  Created by Brook on 2021/8/30.
//  Copyright © 2021 Inspur. All rights reserved.
//

#import "InspurServerConfig.h"
#import "InspurServerUserConfig.h"

NS_ASSUME_NONNULL_BEGIN

@interface InspurServerConfigSynchronizer : NSObject

@property(class, nonatomic, strong)NSString *token;
@property(class, nonatomic, strong)NSArray <NSString *> *hosts;

+ (void)getServerConfigFromServer:(void(^)(InspurServerConfig *config))complete;
+ (void)getServerUserConfigFromServer:(void(^)(InspurServerUserConfig *config))complete;

@end

NS_ASSUME_NONNULL_END
