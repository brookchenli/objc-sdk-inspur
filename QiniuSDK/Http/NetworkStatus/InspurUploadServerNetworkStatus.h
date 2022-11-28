//
//  QNUploadServerNetworkStatus.h
//  QiniuSDK
//
//  Created by yangsen on 2020/11/17.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "InspurUploadServer.h"

NS_ASSUME_NONNULL_BEGIN

@interface InspurUploadServerNetworkStatus : NSObject

+ (InspurUploadServer *)getBetterNetworkServer:(InspurUploadServer *)serverA
                                   serverB:(InspurUploadServer *)serverB;

+ (BOOL)isServerNetworkBetter:(InspurUploadServer *)serverA
                  thanServerB:(InspurUploadServer *)serverB;

@end

NS_ASSUME_NONNULL_END
