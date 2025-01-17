//
//  InspurPartsUploadApiV2.m
//  InspurOSSSDK
//
//  Created by Brook on 2020/11/30.
//  Copyright © 2020 Inspur. All rights reserved.
//

#import "InspurLogUtil.h"
#import "InspurDefine.h"
#import "InspurRequestTransaction.h"
#import "InspurUploadInfoV2.h"
#import "InspurPartsUploadPerformerV2.h"

@interface InspurPartsUploadPerformerV2()
@end
@implementation InspurPartsUploadPerformerV2

- (InspurUploadInfo *)getFileInfoWithDictionary:(NSDictionary *)fileInfoDictionary {
    return [InspurUploadInfoV2 info:self.uploadSource dictionary:fileInfoDictionary];
}

- (InspurUploadInfo *)getDefaultUploadInfo {
    return [InspurUploadInfoV2 info:self.uploadSource configuration:self.config];
}

- (void)serverInit:(void(^)(InspurResponseInfo * _Nullable responseInfo,
                            InspurUploadRegionRequestMetrics * _Nullable metrics,
                            NSDictionary * _Nullable response))completeHandler {
    
    InspurUploadInfoV2 *uploadInfo = (InspurUploadInfoV2 *)self.uploadInfo;
    if (uploadInfo && [uploadInfo isValid]) {
        InspurLogInfo(@"key:%@ serverInit success", self.key);
        InspurResponseInfo *responseInfo = [InspurResponseInfo successResponse];
        completeHandler(responseInfo, nil, nil);
        return;
    }
    
    InspurRequestTransaction *transaction = [self createUploadRequestTransaction];

    kInspurWeakSelf;
    kInspurWeakObj(transaction);
    [transaction initPart:^(InspurResponseInfo * _Nullable responseInfo, InspurUploadRegionRequestMetrics * _Nullable metrics, NSDictionary * _Nullable response) {
        kInspurStrongSelf;
        kInspurStrongObj(transaction);
                
        NSString *uploadId = response[@"InitiateMultipartUploadResult"][@"UploadId"][@"text"];
        NSNumber *expireAt = @(self.token.deadline);
        if (responseInfo.isOK && uploadId && expireAt) {
            uploadInfo.uploadId = uploadId;
            uploadInfo.expireAt = expireAt;
            [self recordUploadInfo];
        }
        
        [self updateKeyIfNeeded:responseInfo];
        
        completeHandler(responseInfo, metrics, response);
        [self destroyUploadRequestTransaction:transaction];
    }];
}

- (void)uploadNextData:(void(^)(BOOL stop,
                                InspurResponseInfo * _Nullable responseInfo,
                                InspurUploadRegionRequestMetrics * _Nullable metrics,
                                NSDictionary * _Nullable response))completeHandler {
    InspurUploadInfoV2 *uploadInfo = (InspurUploadInfoV2 *)self.uploadInfo;
    
    NSError *error = nil;
    InspurUploadData *data = nil;
    @synchronized (self) {
        data = [uploadInfo nextUploadData:&error];
        data.state = InspurUploadStateUploading;
    }
    
    if (error) {
        InspurResponseInfo *responseInfo = [InspurResponseInfo responseInfoWithLocalIOError:[NSString stringWithFormat:@"%@", error]];
        completeHandler(YES, responseInfo, nil, nil);
        return;
    }
    
    // 上传完毕
    if (data == nil) {
        InspurLogInfo(@"key:%@ no data left", self.key);
        
        InspurResponseInfo *responseInfo = nil;
        if (uploadInfo.getSourceSize == 0) {
            responseInfo = [InspurResponseInfo responseInfoOfZeroData:@"file is empty"];
        } else {
            responseInfo = [InspurResponseInfo responseInfoWithSDKInteriorError:@"no chunk left"];
        }
        completeHandler(YES, responseInfo, nil, nil);
        return;
    }
    long long sourceSize = uploadInfo.getSourceSize;
    long long dataSize = data.size;
    long long maxPartNumber = 0;
    if (sourceSize >0 && dataSize > 0) {
        BOOL mod = (sourceSize % dataSize) > 0;
        long long count = (sourceSize / dataSize);
        maxPartNumber = count + (mod ? 1 : 0);
    }    
    kInspurWeakSelf;
    void (^progress)(long long, long long) = ^(long long totalBytesWritten, long long totalBytesExpectedToWrite){
        kInspurStrongSelf;
        data.uploadSize = totalBytesWritten;
        [self notifyProgress:false];
    };
    
    InspurRequestTransaction *transaction = [self createUploadRequestTransaction];
    
    kInspurWeakObj(transaction);
    [transaction uploadPart:uploadInfo.uploadId
                  partIndex:[uploadInfo getPartIndexOfData:data]
                   maxIndex:maxPartNumber
                   partData:data.data
                   progress:progress
                   complete:^(InspurResponseInfo * _Nullable responseInfo, InspurUploadRegionRequestMetrics * _Nullable metrics, NSDictionary * _Nullable response) {
        kInspurStrongSelf;
        kInspurStrongObj(transaction);

        NSString *etag = responseInfo.responseHeader[@"etag"];
        etag = [etag stringByReplacingOccurrencesOfString:@"\"" withString:@""];
        if (responseInfo.isOK && etag) {
            data.etag = etag;
            data.state = InspurUploadStateComplete;
            [self recordUploadInfo];
            [self notifyProgress:false];
        } else {
            data.state = InspurUploadStateWaitToUpload;
        }
        completeHandler(NO, responseInfo, metrics, response);
        [self destroyUploadRequestTransaction:transaction];
    }];
}

- (void)completeUpload:(void(^)(InspurResponseInfo * _Nullable responseInfo,
                                InspurUploadRegionRequestMetrics * _Nullable metrics,
                                NSDictionary * _Nullable response))completeHandler {
    
    InspurUploadInfoV2 *uploadInfo = (InspurUploadInfoV2 *)self.uploadInfo;
    
    NSArray *partInfoArray = [uploadInfo getPartInfoArray];
    InspurRequestTransaction *transaction = [self createUploadRequestTransaction];
    
    kInspurWeakSelf;
    kInspurWeakObj(transaction);
    [transaction completeParts:self.fileName uploadId:uploadInfo.uploadId partInfoArray:partInfoArray complete:^(InspurResponseInfo * _Nullable responseInfo, InspurUploadRegionRequestMetrics * _Nullable metrics, NSDictionary * _Nullable response) {
        kInspurStrongSelf;
        kInspurStrongObj(transaction);
        if (responseInfo.isOK) {
            [self notifyProgress:true];
        }
        completeHandler(responseInfo, metrics, response);
        [self destroyUploadRequestTransaction:transaction];
    }];
}


@end
