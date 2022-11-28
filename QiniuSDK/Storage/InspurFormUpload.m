//
//  QNFormUpload.m
//  QiniuSDK
//
//  Created by bailong on 15/1/4.
//  Copyright (c) 2015年 Qiniu. All rights reserved.
//
#import "QNDefine.h"
#import "InspurLogUtil.h"
#import "InspurFormUpload.h"
#import "InspurResponseInfo.h"
#import "InspurUpProgress.h"
#import "InspurRequestTransaction.h"

@interface InspurFormUpload ()

@property(nonatomic, strong)InspurUpProgress *progress;

@property(nonatomic, strong)InspurRequestTransaction *uploadTransaction;

@end

@implementation InspurFormUpload

- (void)startToUpload {
    [super startToUpload];
    
    QNLogInfo(@"key:%@ form上传", self.key);
    
    self.uploadTransaction = [[InspurRequestTransaction alloc] initWithConfig:self.config
                                                             uploadOption:self.option
                                                             targetRegion:[self getTargetRegion]
                                                            currentRegion:[self getCurrentRegion]
                                                                      key:self.key
                                                                    token:self.token];

    kQNWeakSelf;
    void(^progressHandler)(long long totalBytesWritten, long long totalBytesExpectedToWrite) = ^(long long totalBytesWritten, long long totalBytesExpectedToWrite){
        kQNStrongSelf;
        [self.progress progress:self.key uploadBytes:totalBytesWritten totalBytes:totalBytesExpectedToWrite];
    };
    
    [self.uploadTransaction putData:self.data
                           fileName:self.fileName
                           progress:progressHandler
                           complete:^(InspurResponseInfo * _Nullable responseInfo, InspurUploadRegionRequestMetrics * _Nullable metrics, NSDictionary * _Nullable response) {
        kQNStrongSelf;
        
        [self addRegionRequestMetricsOfOneFlow:metrics];
        
        if (!responseInfo.isOK) {
            if (![self switchRegionAndUploadIfNeededWithErrorResponse:responseInfo]) {
                [self complete:responseInfo response:response];
            }
            return;
        }
        
        [self.progress notifyDone:self.key totalBytes:self.data.length];
        [self complete:responseInfo response:response];
    }];
    
    /*
    [self.uploadTransaction uploadFormData:self.data
                                  fileName:self.fileName
                                  progress:progressHandler
                                  complete:^(QNResponseInfo * _Nullable responseInfo, QNUploadRegionRequestMetrics * _Nullable metrics, NSDictionary * _Nullable response) {
        kQNStrongSelf;
        
        [self addRegionRequestMetricsOfOneFlow:metrics];
        
        if (!responseInfo.isOK) {
            if (![self switchRegionAndUploadIfNeededWithErrorResponse:responseInfo]) {
                [self complete:responseInfo response:response];
            }
            return;
        }
        
        [self.progress notifyDone:self.key totalBytes:self.data.length];
        [self complete:responseInfo response:response];
    }];
     */
}

- (InspurUpProgress *)progress {
    if (_progress == nil) {
        _progress = [InspurUpProgress progress:self.option.progressHandler byteProgress:self.option.byteProgressHandler];
    }
    return _progress;
}

- (NSString *)upType {
    return QNUploadUpTypeForm;
}
@end
