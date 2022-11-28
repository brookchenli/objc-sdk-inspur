//
//  InspurUploadServerFreezeUtil.h
//  InspurOSSSDK
//
//  Created by Brook on 2021/2/4.
//  Copyright © 2021 Inspur. All rights reserved.
//

#import "InspurUploadServerFreezeManager.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

#define kInspurUploadHttp3FrozenTime (3600 * 24)
#define InspurUploadFrozenType(HOST, IP) ([InspurUploadServerFreezeUtil getFrozenType:HOST ip:IP])

#define kInspurUploadGlobalHttp3Freezer [InspurUploadServerFreezeUtil sharedHttp3Freezer]
#define kInspurUploadGlobalHttp2Freezer [InspurUploadServerFreezeUtil sharedHttp2Freezer]

@interface InspurUploadServerFreezeUtil : NSObject

+ (InspurUploadServerFreezeManager *)sharedHttp2Freezer;
+ (InspurUploadServerFreezeManager *)sharedHttp3Freezer;

+ (BOOL)isType:(NSString *)type frozenByFreezeManagers:(NSArray <InspurUploadServerFreezeManager *> *)freezeManagerList;

+ (NSString *)getFrozenType:(NSString *)host ip:(NSString *)ip;

@end

NS_ASSUME_NONNULL_END
