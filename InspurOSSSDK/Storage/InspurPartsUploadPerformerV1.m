//
//  InspurPartsUploadApiV1.m
//  InspurOSSSDK
//
//  Created by Brook on 2020/11/30.
//  Copyright © 2020 Inspur. All rights reserved.
//

#import "InspurLogUtil.h"
#import "InspurDefine.h"
#import "InspurRequestTransaction.h"
#import "InspurUploadInfoV1.h"
#import "InspurPartsUploadPerformerV1.h"

@interface InspurPartsUploadPerformerV1()
@end
@implementation InspurPartsUploadPerformerV1
+ (long long)blockSize{
    return 4 * 1024 * 1024;
}

- (InspurUploadInfo *)getFileInfoWithDictionary:(NSDictionary *)fileInfoDictionary {
    return [InspurUploadInfoV1 info:self.uploadSource dictionary:fileInfoDictionary];
}

- (InspurUploadInfo *)getDefaultUploadInfo {
    return [InspurUploadInfoV1 info:self.uploadSource configuration:self.config];
}

- (void)serverInit:(void(^)(InspurResponseInfo * _Nullable responseInfo,
                            InspurUploadRegionRequestMetrics * _Nullable metrics,
                            NSDictionary * _Nullable response))completeHandler {
    InspurResponseInfo *responseInfo = [InspurResponseInfo successResponse];
    completeHandler(responseInfo, nil, nil);
}

- (void)uploadNextData:(void(^)(BOOL stop,
                                InspurResponseInfo * _Nullable responseInfo,
                                InspurUploadRegionRequestMetrics * _Nullable metrics,
                                NSDictionary * _Nullable response))completeHandler {
    InspurUploadInfoV1 *uploadInfo = (InspurUploadInfoV1 *)self.uploadInfo;
    
    NSError *error;
    InspurUploadBlock *block = nil;
    InspurUploadData *chunk = nil;
    @synchronized (self) {
        block = [uploadInfo nextUploadBlock:&error];
        chunk = [uploadInfo nextUploadData:block];
        chunk.state = QNUploadStateUploading;
    }

    if (error) {
        InspurResponseInfo *responseInfo = [InspurResponseInfo responseInfoWithLocalIOError:[NSString stringWithFormat:@"%@", error]];
        completeHandler(YES, responseInfo, nil, nil);
        return;
    }
    
    if (block == nil || chunk == nil) {
        InspurLogInfo(@"key:%@ no chunk left", self.key);
        
        InspurResponseInfo *responseInfo = nil;
        if (uploadInfo.getSourceSize == 0) {
            responseInfo = [InspurResponseInfo responseInfoOfZeroData:@"file is empty"];
        } else {
            responseInfo = [InspurResponseInfo responseInfoWithSDKInteriorError:@"no chunk left"];
        }
        completeHandler(YES, responseInfo, nil, nil);
        return;
    }
    
    if (chunk.data == nil) {
        InspurLogInfo(@"key:%@ chunk data is nil", self.key);
        
        InspurResponseInfo *responseInfo = [InspurResponseInfo responseInfoOfZeroData:@"chunk data is nil"];;
        completeHandler(YES, responseInfo, nil, nil);
        return;
    }
    
    kInspurWeakSelf;
    void (^progress)(long long, long long) = ^(long long totalBytesWritten, long long totalBytesExpectedToWrite){
        kInspurStrongSelf;
        chunk.uploadSize = totalBytesWritten;
        [self notifyProgress:false];
    };
    
    void (^completeHandlerP)(InspurResponseInfo *, InspurUploadRegionRequestMetrics *, NSDictionary *) = ^(InspurResponseInfo * _Nullable responseInfo, InspurUploadRegionRequestMetrics * _Nullable metrics, NSDictionary * _Nullable response) {
        kInspurStrongSelf;
        
        NSString *blockContext = response[@"ctx"];
        NSNumber *expiredAt = response[@"expired_at"];
        if (responseInfo.isOK && blockContext && expiredAt) {
            block.context = blockContext;
            block.expiredAt = expiredAt;
            chunk.state = QNUploadStateComplete;
            [self recordUploadInfo];
            [self notifyProgress:false];
        } else {
            chunk.state = QNUploadStateWaitToUpload;
        }
        completeHandler(NO, responseInfo, metrics, response);
    };
    
    if ([uploadInfo isFirstData:chunk]) {
        InspurLogInfo(@"key:%@ makeBlock", self.key);
        [self makeBlock:block firstChunk:chunk chunkData:chunk.data progress:progress completeHandler:completeHandlerP];
    } else {
        InspurLogInfo(@"key:%@ uploadChunk", self.key);
        [self uploadChunk:block chunk:chunk chunkData:chunk.data progress:progress completeHandler:completeHandlerP];
    }
}

- (void)completeUpload:(void(^)(InspurResponseInfo * _Nullable responseInfo,
                                InspurUploadRegionRequestMetrics * _Nullable metrics,
                                NSDictionary * _Nullable response))completeHandler {
    InspurUploadInfoV1 *uploadInfo = (InspurUploadInfoV1 *)self.uploadInfo;
    
    InspurRequestTransaction *transaction = [self createUploadRequestTransaction];
    
    kInspurWeakSelf;
    kInspurWeakObj(transaction);
    [transaction makeFile:[uploadInfo getSourceSize]
                 fileName:self.fileName
            blockContexts:[uploadInfo allBlocksContexts]
                 complete:^(InspurResponseInfo * _Nullable responseInfo, InspurUploadRegionRequestMetrics * _Nullable metrics, NSDictionary * _Nullable response) {
        kInspurStrongSelf;
        kInspurStrongObj(transaction);
        if (responseInfo.isOK) {
            [self notifyProgress:true];
        }
        completeHandler(responseInfo, metrics, response);
        [self destroyUploadRequestTransaction:transaction];
    }];
}


- (void)makeBlock:(InspurUploadBlock *)block
       firstChunk:(InspurUploadData *)chunk
        chunkData:(NSData *)chunkData
         progress:(void(^)(long long totalBytesWritten,
                           long long totalBytesExpectedToWrite))progress
  completeHandler:(void(^)(InspurResponseInfo * _Nullable responseInfo,
                           InspurUploadRegionRequestMetrics * _Nullable metrics,
                           NSDictionary * _Nullable response))completeHandler {
    
    InspurRequestTransaction *transaction = [self createUploadRequestTransaction];
    kInspurWeakSelf;
    kInspurWeakObj(transaction);
    [transaction makeBlock:block.offset
                 blockSize:block.size
            firstChunkData:chunkData
                  progress:progress
                  complete:^(InspurResponseInfo * _Nullable responseInfo, InspurUploadRegionRequestMetrics * _Nullable metrics, NSDictionary * _Nullable response) {
        kInspurStrongSelf;
        kInspurStrongObj(transaction);
        
        completeHandler(responseInfo, metrics, response);
        [self destroyUploadRequestTransaction:transaction];
    }];
}


- (void)uploadChunk:(InspurUploadBlock *)block
              chunk:(InspurUploadData *)chunk
          chunkData:(NSData *)chunkData
           progress:(void(^)(long long totalBytesWritten,
                             long long totalBytesExpectedToWrite))progress
    completeHandler:(void(^)(InspurResponseInfo * _Nullable responseInfo,
                             InspurUploadRegionRequestMetrics * _Nullable metrics,
                             NSDictionary * _Nullable response))completeHandler {
    
    InspurRequestTransaction *transaction = [self createUploadRequestTransaction];
    kInspurWeakSelf;
    kInspurWeakObj(transaction);
    [transaction uploadChunk:block.context
                 blockOffset:block.offset
                   chunkData:chunkData
                 chunkOffset:chunk.offset
                    progress:progress
                    complete:^(InspurResponseInfo * _Nullable responseInfo, InspurUploadRegionRequestMetrics * _Nullable metrics, NSDictionary * _Nullable response) {
        kInspurStrongSelf;
        kInspurStrongObj(transaction);
        
        completeHandler(responseInfo, metrics, response);
        [self destroyUploadRequestTransaction:transaction];
    }];
}

@end
