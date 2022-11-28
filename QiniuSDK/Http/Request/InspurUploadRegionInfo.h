//
//  QNUploadRegion.h
//  QiniuSDK_Mac
//
//  Created by Brook on 2020/4/30.
//  Copyright © 2020 Inspur. All rights reserved.
//

#import "InspurIUploadServer.h"

NS_ASSUME_NONNULL_BEGIN

@class InspurZoneInfo, InspurUploadRequestState, InspurResponseInfo;

@protocol InspurUploadRegion <NSObject>

@property(nonatomic, assign, readonly)BOOL isValid;
@property(nonatomic, strong, nullable, readonly)InspurZoneInfo *zoneInfo;

- (void)setupRegionData:(InspurZoneInfo * _Nullable)zoneInfo;

- (id<InspurUploadServer> _Nullable)getNextServer:(InspurUploadRequestState *)requestState
                                 responseInfo:(InspurResponseInfo *)responseInfo
                                 freezeServer:(id <InspurUploadServer> _Nullable)freezeServer;

- (void)updateIpListFormHost:(NSString *)host;

@end

NS_ASSUME_NONNULL_END
