//
//  QNUploadServerFreezeUtil.h
//  QiniuSDK
//
//  Created by Brook on 2021/2/4.
//  Copyright © 2021 Inspur. All rights reserved.
//

#import "InspurUploadServerFreezeManager.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

#define kQNUploadHttp3FrozenTime (3600 * 24)
#define QNUploadFrozenType(HOST, IP) ([InspurUploadServerFreezeUtil getFrozenType:HOST ip:IP])

#define kQNUploadGlobalHttp3Freezer [InspurUploadServerFreezeUtil sharedHttp3Freezer]
#define kQNUploadGlobalHttp2Freezer [InspurUploadServerFreezeUtil sharedHttp2Freezer]

@interface InspurUploadServerFreezeUtil : NSObject

+ (InspurUploadServerFreezeManager *)sharedHttp2Freezer;
+ (InspurUploadServerFreezeManager *)sharedHttp3Freezer;

+ (BOOL)isType:(NSString *)type frozenByFreezeManagers:(NSArray <InspurUploadServerFreezeManager *> *)freezeManagerList;

+ (NSString *)getFrozenType:(NSString *)host ip:(NSString *)ip;

@end

NS_ASSUME_NONNULL_END
