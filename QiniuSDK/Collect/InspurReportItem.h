//
//  QNReportItem.h
//  InspurOSSSDK
//
//  Created by Brook on 2020/5/12.
//  Copyright © 2020 Inspur. All rights reserved.
//

#import "InspurUploadInfoReporter.h"
#import "InspurResponseInfo.h"

NS_ASSUME_NONNULL_BEGIN

@interface InspurReportItem : NSObject

+ (instancetype)item;

/// 设置打点日志字段
/// @param value log value
/// @param key log key
- (void)setReportValue:(id _Nullable)value forKey:(NSString * _Nullable)key;

/// 移除打点日志字段
/// @param key log key
- (void)removeReportValueForKey:(NSString * _Nullable)key;

@end


@interface InspurUploadInfoReporter(ReportItem)

- (void)reportItem:(InspurReportItem *)item token:(NSString *)token;

@end


@interface InspurResponseInfo(Report)

@property(nonatomic, assign, readonly)NSNumber *requestReportStatusCode;
@property(nonatomic,   copy, readonly)NSString *requestReportErrorType;

@property(nonatomic,   copy, readonly)NSString *qualityResult;

@end



//MARK:-- 日志类型
extern NSString *const QNReportLogTypeRequest;
extern NSString *const QNReportLogTypeBlock;
extern NSString *const QNReportLogTypeQuality;

//MARK:-- 请求信息打点⽇志
extern NSString *const InspurReportRequestKeyLogType;
extern NSString *const InspurReportRequestKeyUpTime;
extern NSString *const InspurReportRequestKeyStatusCode;
extern NSString *const InspurReportRequestKeyRequestId;
extern NSString *const InspurReportRequestKeyHost;
extern NSString *const InspurReportRequestKeyHttpVersion;
extern NSString *const InspurReportRequestKeyRemoteIp;
extern NSString *const InspurReportRequestKeyPort;
extern NSString *const InspurReportRequestKeyTargetBucket;
extern NSString *const InspurReportRequestKeyTargetKey;
extern NSString *const InspurReportRequestKeyTotalElapsedTime;
extern NSString *const InspurReportRequestKeyDnsElapsedTime;
extern NSString *const InspurReportRequestKeyConnectElapsedTime;
extern NSString *const InspurReportRequestKeyTLSConnectElapsedTime;
extern NSString *const InspurReportRequestKeyRequestElapsedTime;
extern NSString *const InspurReportRequestKeyWaitElapsedTime;
extern NSString *const InspurReportRequestKeyResponseElapsedTime;
extern NSString *const InspurReportRequestKeyFileOffset;
extern NSString *const InspurReportRequestKeyBytesSent;
extern NSString *const InspurReportRequestKeyBytesTotal;
extern NSString *const InspurReportRequestKeyPid;
extern NSString *const InspurReportRequestKeyTid;
extern NSString *const InspurReportRequestKeyTargetRegionId;
extern NSString *const InspurReportRequestKeyCurrentRegionId;
extern NSString *const InspurReportRequestKeyErrorType;
extern NSString *const InspurReportRequestKeyErrorDescription;
extern NSString *const InspurReportRequestKeyUpType;
extern NSString *const InspurReportRequestKeyOsName;
extern NSString *const InspurReportRequestKeyOsVersion;
extern NSString *const InspurReportRequestKeySDKName;
extern NSString *const InspurReportRequestKeySDKVersion;
extern NSString *const InspurReportRequestKeyClientTime;
extern NSString *const InspurReportRequestKeyHttpClient;
extern NSString *const InspurReportRequestKeyNetworkType;
extern NSString *const InspurReportRequestKeySignalStrength;
extern NSString *const InspurReportRequestKeyPrefetchedDnsSource;
extern NSString *const InspurReportRequestKeyDnsSource;
extern NSString *const InspurReportRequestKeyDnsErrorMessage;
extern NSString *const InspurReportRequestKeyPrefetchedBefore;
extern NSString *const InspurReportRequestKeyPrefetchedErrorMessage;
extern NSString *const InspurReportRequestKeyNetworkMeasuring;
extern NSString *const InspurReportRequestKeyPerceptiveSpeed;
extern NSString *const InspurReportRequestKeyHijacking;

//MARK:-- 分块上传统计⽇志
extern NSString *const InspurReportBlockKeyLogType;
extern NSString *const InspurReportBlockKeyUpTime;
extern NSString *const InspurReportBlockKeyTargetBucket;
extern NSString *const InspurReportBlockKeyTargetKey;
extern NSString *const InspurReportBlockKeyTargetRegionId;
extern NSString *const InspurReportBlockKeyCurrentRegionId;
extern NSString *const InspurReportBlockKeyTotalElapsedTime;
extern NSString *const InspurReportBlockKeyBytesSent;
extern NSString *const InspurReportBlockKeyRecoveredFrom;
extern NSString *const InspurReportBlockKeyFileSize;
extern NSString *const InspurReportBlockKeyPid;
extern NSString *const InspurReportBlockKeyTid;
extern NSString *const InspurReportBlockKeyUpApiVersion;
extern NSString *const InspurReportBlockKeyClientTime;
extern NSString *const InspurReportBlockKeyOsName;
extern NSString *const InspurReportBlockKeyOsVersion;
extern NSString *const InspurReportBlockKeySDKName;
extern NSString *const InspurReportBlockKeySDKVersion;
extern NSString *const InspurReportBlockKeyPerceptiveSpeed;
extern NSString *const InspurReportBlockKeyHijacking;

//MARK:-- 上传质量统计
extern NSString *const InspurReportQualityKeyLogType;
extern NSString *const InspurReportQualityKeyUpType;
extern NSString *const InspurReportQualityKeyUpTime;
extern NSString *const InspurReportQualityKeyResult;
extern NSString *const InspurReportQualityKeyTargetBucket;
extern NSString *const InspurReportQualityKeyTargetKey;
extern NSString *const InspurReportQualityKeyTotalElapsedTime;
extern NSString *const InspurReportQualityKeyUcQueryElapsedTime;
extern NSString *const InspurReportQualityKeyRequestsCount;
extern NSString *const InspurReportQualityKeyRegionsCount;
extern NSString *const InspurReportQualityKeyBytesSent;
extern NSString *const InspurReportQualityKeyFileSize;
extern NSString *const InspurReportQualityKeyCloudType;
extern NSString *const InspurReportQualityKeyErrorType;
extern NSString *const InspurReportQualityKeyErrorDescription;
extern NSString *const InspurReportQualityKeyOsName;
extern NSString *const InspurReportQualityKeyOsVersion;
extern NSString *const InspurReportQualityKeySDKName;
extern NSString *const InspurReportQualityKeySDKVersion;
extern NSString *const InspurReportQualityKeyPerceptiveSpeed;
extern NSString *const InspurReportQualityKeyHijacking;

NS_ASSUME_NONNULL_END
