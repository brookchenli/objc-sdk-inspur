//
//  QNUploadServerNetworkStatus.h
//  InspurOSSSDK
//
//  Created by Brook on 2020/11/17.
//  Copyright © 2020 Inspur. All rights reserved.
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
