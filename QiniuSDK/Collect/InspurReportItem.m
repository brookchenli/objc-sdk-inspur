//
//  QNReportItem.m
//  QiniuSDK
//
//  Created by Brook on 2020/5/12.
//  Copyright © 2020 Inspur. All rights reserved.
//

#import "InspurReportItem.h"
#import "InspurAsyncRun.h"
#import "InspurLogUtil.h"

@interface InspurReportItem()

@property(nonatomic, strong)NSMutableDictionary *keyValues;

@end
@implementation InspurReportItem

+ (instancetype)item{
    InspurReportItem *item = [[InspurReportItem alloc] init];
    return item;
}

- (instancetype)init{
    if (self = [super init]) {
        [self initData];
    }
    return self;
}

- (void)initData{
    _keyValues = [NSMutableDictionary dictionary];
}

- (void)setReportValue:(id _Nullable)value forKey:(NSString * _Nullable)key{
    if (!value || !key || ![key isKindOfClass:[NSString class]]) {
        return;
    }
    [self.keyValues setValue:value forKey:key];
}

- (void)removeReportValueForKey:(NSString * _Nullable)key{
    if (!key) {
        return;
    }
    [self.keyValues removeObjectForKey:key];
}


- (NSString *)toJson{
    
    NSString *jsonString = @"{}";
    if (!self.keyValues || self.keyValues.count == 0) {
        return jsonString;
    }
    
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:self.keyValues
                                                       options:NSJSONWritingFragmentsAllowed
                                                         error:nil];
    if (!jsonData) {
        return jsonString;
    }
    
    jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    return jsonString;
}

@end

@implementation InspurUploadInfoReporter(ReportItem)

- (void)reportItem:(InspurReportItem *)item token:(NSString *)token{
    InspurAsyncRun(^{
        NSString *itemJsonString = [item toJson];
        QNLogInfo(@"up log:%@", itemJsonString);
        if (itemJsonString && ![itemJsonString isEqualToString:@"{}"]) {
            [self report:itemJsonString token:token];
        }
    });
}

@end

@implementation InspurResponseInfo(Report)

- (NSNumber *)requestReportStatusCode{
    return @(self.statusCode);
}

- (NSString *)requestReportErrorType{
    NSString *errorType = nil;
    if (self.statusCode == -1){
        errorType = @"network_error";
    } else if (self.statusCode == kInspurLocalIOError){
        errorType = @"local_io_error";
    } else if (self.statusCode == 100){
        errorType = @"protocol_error";
    } else if (self.statusCode > 199 && self.statusCode < 300) {
//        NSURLErrorFailingURLErrorKey
    } else if (self.statusCode > 299){
        errorType = @"response_error";
    } else if (self.statusCode == -1003){
        errorType = @"unknown_host";
    } else if (self.statusCode == -1009){
           errorType = @"network_slow";
    } else if (self.statusCode == -1001){
           errorType = @"timeout";
    } else if (self.statusCode == -1004){
        errorType = @"cannot_connect_to_host";
    } else if (self.statusCode == -1005 || self.statusCode == -1021){
        errorType = @"transmission_error";
    } else if ((self.statusCode <= -1200 && self.statusCode >= -1206) || self.statusCode == -2000 || self.statusCode == -9807){
        errorType = @"ssl_error";
    } else if (self.statusCode == -1015 || self.statusCode == -1016 || self.statusCode == -1017){
        errorType = @"parse_error";
    } else if (self.statusCode == -1007 || self.statusCode == -1010 || self.statusCode == kInspurMaliciousResponseError){
        errorType = @"malicious_response";
    } else if (self.statusCode == kInspurUnexpectedSysCallError
               || (self.statusCode > -1130 && self.statusCode <= -1010)){
        errorType = @"unexpected_syscall_error";
    } else if (self.statusCode == kInspurRequestCancelled
               || self.statusCode == NSURLErrorCancelled){
        errorType = @"user_canceled";
    } else {
        errorType = @"unknown_error";
    }
    return errorType;
}

- (NSString *)qualityResult{
    
    NSString *result = nil;
    
    if (self.statusCode > 199 && self.statusCode < 300) {
        result = @"ok";
    } else if (self.statusCode > 399 &&
               (self.statusCode < 500 || self.statusCode == 573 || self.statusCode == 579 ||
                self.statusCode == 608 || self.statusCode == 612 || self.statusCode == 614 || self.statusCode == 630 || self.statusCode == 631 ||
                self.statusCode == 701)) {
        result = @"bad_request";
    } else if (self.statusCode == kInspurZeroDataSize){
        result = @"zero_size_file";
    } else if (self.statusCode == kInspurFileError){
        result = @"invalid_file";
    } else if (self.statusCode == kInspurInvalidToken
            || self.statusCode == kInspurInvalidArgument){
        result = @"invalid_args";
    }
    
    if (result == nil) {
        result = [self requestReportErrorType];
    }
    
    return result;
}

@end


//MARK:-- 日志类型
NSString * const QNReportLogTypeRequest = @"request";
NSString * const QNReportLogTypeBlock = @"block";
NSString * const QNReportLogTypeQuality = @"quality";


//MARK:-- 请求信息打点⽇志
NSString * const InspurReportRequestKeyLogType = @"log_type";
NSString * const InspurReportRequestKeyUpTime = @"up_time";
NSString * const InspurReportRequestKeyStatusCode = @"status_code";
NSString * const InspurReportRequestKeyRequestId = @"req_id";
NSString * const InspurReportRequestKeyHost = @"host";
NSString * const InspurReportRequestKeyHttpVersion = @"http_version";
NSString * const InspurReportRequestKeyRemoteIp = @"remote_ip";
NSString * const InspurReportRequestKeyPort = @"port";
NSString * const InspurReportRequestKeyTargetBucket = @"target_bucket";
NSString * const InspurReportRequestKeyTargetKey = @"target_key";
NSString * const InspurReportRequestKeyTotalElapsedTime = @"total_elapsed_time";
NSString * const InspurReportRequestKeyDnsElapsedTime = @"dns_elapsed_time";
NSString * const InspurReportRequestKeyConnectElapsedTime = @"connect_elapsed_time";
NSString * const InspurReportRequestKeyTLSConnectElapsedTime = @"tls_connect_elapsed_time";
NSString * const InspurReportRequestKeyRequestElapsedTime = @"request_elapsed_time";
NSString * const InspurReportRequestKeyWaitElapsedTime = @"wait_elapsed_time";
NSString * const InspurReportRequestKeyResponseElapsedTime = @"response_elapsed_time";
NSString * const InspurReportRequestKeyFileOffset = @"file_offset";
NSString * const InspurReportRequestKeyBytesSent = @"bytes_sent";
NSString * const InspurReportRequestKeyBytesTotal = @"bytes_total";
NSString * const InspurReportRequestKeyPid = @"pid";
NSString * const InspurReportRequestKeyTid = @"tid";
NSString * const InspurReportRequestKeyTargetRegionId = @"target_region_id";
NSString * const InspurReportRequestKeyCurrentRegionId = @"current_region_id";
NSString * const InspurReportRequestKeyErrorType = @"error_type";
NSString * const InspurReportRequestKeyErrorDescription = @"error_description";
NSString * const InspurReportRequestKeyUpType = @"up_type";
NSString * const InspurReportRequestKeyOsName = @"os_name";
NSString * const InspurReportRequestKeyOsVersion = @"os_version";
NSString * const InspurReportRequestKeySDKName = @"sdk_name";
NSString * const InspurReportRequestKeySDKVersion = @"sdk_version";
NSString * const InspurReportRequestKeyClientTime = @"client_time";
NSString * const InspurReportRequestKeyHttpClient = @"http_client";
NSString * const InspurReportRequestKeyNetworkType = @"network_type";
NSString * const InspurReportRequestKeySignalStrength = @"signal_strength";
NSString * const InspurReportRequestKeyPrefetchedDnsSource = @"prefetched_dns_source";
NSString * const InspurReportRequestKeyDnsSource = @"dns_source";
NSString * const InspurReportRequestKeyDnsErrorMessage = @"dns_error_message";
NSString * const InspurReportRequestKeyPrefetchedBefore = @"prefetched_before";
NSString * const InspurReportRequestKeyPrefetchedErrorMessage = @"prefetched_error_message";
NSString * const InspurReportRequestKeyNetworkMeasuring = @"network_measuring";
NSString * const InspurReportRequestKeyPerceptiveSpeed = @"perceptive_speed";
NSString * const InspurReportRequestKeyHijacking = @"hijacking";

//MARK:-- 分块上传统计⽇志
NSString * const InspurReportBlockKeyLogType = @"log_type";
NSString * const InspurReportBlockKeyUpTime = @"up_time";
NSString * const InspurReportBlockKeyTargetBucket = @"target_bucket";
NSString * const InspurReportBlockKeyTargetKey = @"target_key";
NSString * const InspurReportBlockKeyTargetRegionId = @"target_region_id";
NSString * const InspurReportBlockKeyCurrentRegionId = @"current_region_id";
NSString * const InspurReportBlockKeyTotalElapsedTime = @"total_elapsed_time";
NSString * const InspurReportBlockKeyBytesSent = @"bytes_sent";
NSString * const InspurReportBlockKeyRecoveredFrom = @"recovered_from";
NSString * const InspurReportBlockKeyFileSize = @"file_size";
NSString * const InspurReportBlockKeyPid = @"pid";
NSString * const InspurReportBlockKeyTid = @"tid";
NSString * const InspurReportBlockKeyUpApiVersion = @"up_api_version";
NSString * const InspurReportBlockKeyClientTime = @"client_time";
NSString * const InspurReportBlockKeyOsName = @"os_name";
NSString * const InspurReportBlockKeyOsVersion = @"os_version";
NSString * const InspurReportBlockKeySDKName = @"sdk_name";
NSString * const InspurReportBlockKeySDKVersion = @"sdk_version";
NSString * const InspurReportBlockKeyPerceptiveSpeed = @"perceptive_speed";
NSString * const InspurReportBlockKeyHijacking = @"hijacking";


//MARK:-- 上传质量统计
NSString * const InspurReportQualityKeyLogType = @"log_type";
NSString * const InspurReportQualityKeyUpType = @"up_type";
NSString * const InspurReportQualityKeyUpTime = @"up_time";
NSString * const InspurReportQualityKeyResult = @"result";
NSString * const InspurReportQualityKeyTargetBucket = @"target_bucket";
NSString * const InspurReportQualityKeyTargetKey = @"target_key";
NSString * const InspurReportQualityKeyTotalElapsedTime = @"total_elapsed_time";
NSString * const InspurReportQualityKeyUcQueryElapsedTime = @"uc_query_elapsed_time";
NSString * const InspurReportQualityKeyRequestsCount = @"requests_count";
NSString * const InspurReportQualityKeyRegionsCount = @"regions_count";
NSString * const InspurReportQualityKeyBytesSent = @"bytes_sent";
NSString * const InspurReportQualityKeyFileSize = @"file_size";
NSString * const InspurReportQualityKeyCloudType = @"cloud_type";
NSString * const InspurReportQualityKeyErrorType = @"error_type";
NSString * const InspurReportQualityKeyErrorDescription = @"error_description";
NSString * const InspurReportQualityKeyOsName = @"os_name";
NSString * const InspurReportQualityKeyOsVersion = @"os_version";
NSString * const InspurReportQualityKeySDKName = @"sdk_name";
NSString * const InspurReportQualityKeySDKVersion = @"sdk_version";
NSString * const InspurReportQualityKeyPerceptiveSpeed = @"perceptive_speed";
NSString * const InspurReportQualityKeyHijacking = @"hijacking";
