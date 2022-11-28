//
//  InspurUploadRequestInfo.h
//  InspurOSSSDK_Mac
//
//  Created by Brook on 2020/5/13.
//  Copyright © 2020 Inspur. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface InspurUploadRequestInfo : NSObject

/// 当前请求的类型
@property(nonatomic,   copy, nullable)NSString *requestType;

/// 上传的bucket
@property(nonatomic,   copy, nullable)NSString *bucket;
/// 上传的key
@property(nonatomic,   copy, nullable)NSString *key;
/// 上传数据的偏移量
@property(nonatomic, strong, nullable)NSNumber *fileOffset;
/// 上传的目标region
@property(nonatomic,   copy, nullable)NSString *targetRegionId;
/// 当前上传的region
@property(nonatomic,   copy, nullable)NSString *currentRegionId;

- (BOOL)shouldReportRequestLog;

@end

extern NSString *const InspurUploadRequestTypeUCQuery;
extern NSString *const InspurUploadRequestTypeForm;
extern NSString *const InspurUploadRequestTypeMkblk;
extern NSString *const InspurUploadRequestTypeBput;
extern NSString *const InspurUploadRequestTypeMkfile;
extern NSString *const InspurUploadRequestTypeInitParts;
extern NSString *const InspurUploadRequestTypeUploadPart;
extern NSString *const InspurUploadRequestTypeCompletePart;
extern NSString *const InspurUploadRequestTypeServerConfig;
extern NSString *const InspurUploadRequestTypeServerUserConfig;
extern NSString *const InspurUploadRequestTypeUpLog;

NS_ASSUME_NONNULL_END
