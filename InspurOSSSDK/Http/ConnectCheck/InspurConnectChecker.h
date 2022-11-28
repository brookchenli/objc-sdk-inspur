//
//  inspurConnectChecker.h
//  InspurOSSSDK_Mac
//
//  Created by Brook on 2021/1/8.
//  Copyright © 2021 Inspur. All rights reserved.
//

#import "InspurUploadRequestMetrics.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface InspurConnectChecker : NSObject

+ (InspurUploadSingleRequestMetrics *)check;

+ (BOOL)isConnected:(InspurUploadSingleRequestMetrics *)metrics;

@end

NS_ASSUME_NONNULL_END
