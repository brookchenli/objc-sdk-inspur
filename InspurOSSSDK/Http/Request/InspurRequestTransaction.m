//
//  InspurRequestTransaction.m
//  InspurOSSSDK
//
//  Created by Brook on 2020/4/30.
//  Copyright © 2020 Inspur. All rights reserved.
//

#import "InspurRequestTransaction.h"

#import "InspurDefine.h"
#import "InspurUtils.h"
#import "InspurCrc32.h"
#import "NSData+InspurMD5.h"
#import "InspurUrlSafeBase64.h"
#import "InspurUpToken.h"
#import "InspurConfiguration.h"
#import "InspurUploadOption.h"
#import "InspurZoneInfo.h"
#import "InspurUserAgent.h"
#import "InspurResponseInfo.h"
#import "InspurUploadRequestState.h"
#import "InspurUploadRequestMetrics.h"

#import "InspurUploadDomainRegion.h"
#import "InspurHttpRegionRequest.h"
#import "InspurSignatureContentGenerator.h"

@interface InspurRequestTransaction()

@property(nonatomic, strong)InspurConfiguration *config;
@property(nonatomic, strong)InspurUploadOption *uploadOption;
@property(nonatomic,   copy)NSString *key;
@property(nonatomic, strong)InspurUpToken *token;

@property(nonatomic, strong)InspurUploadRequestInfo *requestInfo;
@property(nonatomic, strong)InspurUploadRequestState *requestState;
@property(nonatomic, strong)InspurHttpRegionRequest *regionRequest;
@property(nonatomic, strong)InspurSignatureContentGenerator *signatureContentGenerator;

@end
@implementation InspurRequestTransaction

- (instancetype)initWithHosts:(NSArray <NSString *> *)hosts
                     regionId:(NSString * _Nullable)regionId
                        token:(InspurUpToken *)token{
    return [self initWithConfig:[InspurConfiguration defaultConfiguration]
                   uploadOption:[InspurUploadOption defaultOptions]
                          hosts:hosts
                       regionId:regionId
                            key:nil
                          token:token];
}

- (instancetype)initWithConfig:(InspurConfiguration *)config
                  uploadOption:(InspurUploadOption *)uploadOption
                         hosts:(NSArray <NSString *> *)hosts
                      regionId:(NSString * _Nullable)regionId
                           key:(NSString * _Nullable)key
                         token:(nonnull InspurUpToken *)token{
    
    InspurUploadDomainRegion *region = [[InspurUploadDomainRegion alloc] init];
    [region setupRegionData:[InspurZoneInfo zoneInfoWithMainHosts:hosts regionId:regionId]];
    return [self initWithConfig:config
                   uploadOption:uploadOption
                   targetRegion:region
                  currentRegion:region
                            key:key
                          token:token];
}

- (instancetype)initWithConfig:(InspurConfiguration *)config
                  uploadOption:(InspurUploadOption *)uploadOption
                  targetRegion:(id <InspurUploadRegion>)targetRegion
                 currentRegion:(id <InspurUploadRegion>)currentRegion
                           key:(NSString *)key
                         token:(InspurUpToken *)token{
    if (self = [super init]) {
        _config = config;
        _uploadOption = uploadOption;
        _requestState = [[InspurUploadRequestState alloc] init];
        _key = key;
        _token = token;
        _requestInfo = [[InspurUploadRequestInfo alloc] init];
        _requestInfo.targetRegionId = targetRegion.zoneInfo.regionId;
        _requestInfo.currentRegionId = currentRegion.zoneInfo.regionId;
        _requestInfo.bucket = token.bucket;
        _requestInfo.key = key;
        _regionRequest = [[InspurHttpRegionRequest alloc] initWithConfig:config
                                                        uploadOption:uploadOption
                                                               token:token
                                                              region:currentRegion
                                                         requestInfo:_requestInfo
                                                        requestState:_requestState];
        _regionRequest.domin = self.token.domin;
        [self setupSignatureInfo];
    }
    return self;
}

- (void)setupSignatureInfo {
    InspurSignatureContentGenerator *generator = [[InspurSignatureContentGenerator alloc] init];
    generator.bucket = self.token.bucket;
    generator.key = _key;
    generator.deadLine = self.token.deadline;
    generator.accessKey = self.token.access;
    self.signatureContentGenerator = generator;
}

//MARK: -- uc query
- (void)queryUploadHosts:(InspurRequestTransactionCompleteHandler)complete{
    
    self.requestInfo.requestType = InspurUploadRequestTypeUCQuery;
    
    BOOL (^shouldRetry)(InspurResponseInfo *, NSDictionary *) = ^(InspurResponseInfo * responseInfo, NSDictionary * response){
        return (BOOL)!responseInfo.isOK;
    };
    
    NSDictionary *header = @{@"User-Agent" : [kInspurUserAgent getUserAgent:self.token.token]};
    NSString *action = [NSString stringWithFormat:@"/v4/query?ak=%@&bucket=%@&sdk_name=%@&sdk_version=%@", self.token.access, self.token.bucket, [InspurUtils sdkLanguage], [InspurUtils sdkVersion]];
    [self.regionRequest get:action
                    headers:header
                shouldRetry:shouldRetry
                   complete:complete];
}

- (void)putData:(NSData *)data
       fileName:(NSString *)fileName
       progress:(void(^)(long long totalBytesWritten, long long totalBytesExpectedToWrite))progress
       complete:(InspurRequestTransactionCompleteHandler)complete {
    NSMutableString *action = [NSMutableString stringWithFormat:@"/%@", self.token.bucket];
    NSMutableDictionary *header = [NSMutableDictionary dictionary];
    if (self.key) {
        [action appendFormat:@"/%@", self.key];
    } else {
        [action appendFormat:@"/%@", [self.signatureContentGenerator safeKey]];
    }
    [action appendFormat:@"?AccessKeyId=%@&Expires=%@", self.token.access, @(self.token.deadline)];
    if (!self.key) {
        [action appendString:@"&random-object-name=true"];
    }
    
    BOOL (^shouldRetry)(InspurResponseInfo *, NSDictionary *) = ^(InspurResponseInfo * responseInfo, NSDictionary * response){
        return (BOOL)!responseInfo.isOK;
    };
    
    kInspurWeakSelf;
    
    NSString *contentNeedSignature = [self.signatureContentGenerator putData];
    NSLog(@"contentNeedSignature:%@", contentNeedSignature);
    self.token.signatureHandler(@[contentNeedSignature], ^(NSArray<NSString *> * _Nullable signaturedContents, NSError * _Nullable error) {
        kInspurStrongSelf;
        NSString *signature = [NSString stringWithFormat:@"%@", signaturedContents.count > 0 ? signaturedContents.firstObject : @""];
        [action appendFormat:@"&Signature=%@", signature ?: @""];
        [self.regionRequest put:action
                        headers:header
                           body:data
                    shouldRetry:shouldRetry
                       progress:progress
                       complete:complete];
    });
}




//MARK: -- upload form
- (void)uploadFormData:(NSData *)data
              fileName:(NSString *)fileName
              progress:(void(^)(long long totalBytesWritten, long long totalBytesExpectedToWrite))progress
              complete:(InspurRequestTransactionCompleteHandler)complete{

    self.requestInfo.requestType = InspurUploadRequestTypeForm;
    
    NSMutableDictionary *param = [NSMutableDictionary dictionary];
    if (self.uploadOption.params) {
        [param addEntriesFromDictionary:self.uploadOption.params];
    }
    if (self.uploadOption.metaDataParam) {
        [param addEntriesFromDictionary:self.uploadOption.metaDataParam];
    }
    if (self.key && self.key.length > 0) {
        param[@"key"] = self.key;
    }
    param[@"token"] = self.token.token ?: @"";
    if (self.uploadOption.checkCrc) {
        param[@"crc32"] = [NSString stringWithFormat:@"%u", (unsigned int)[InspurCrc32 data:data]];
    }
    
    NSString *boundary = @"werghnvt54wef654rjuhgb56trtg34tweuyrgf";
    NSString *disposition = @"Content-Disposition: form-data";
    
    NSMutableData *body = [NSMutableData data];
    @try {
        for (NSString *paramsKey in param) {
            NSString *pair = [NSString stringWithFormat:@"--%@\r\n%@; name=\"%@\"\r\n\r\n", boundary, disposition, paramsKey];
            [body appendData:[pair dataUsingEncoding:NSUTF8StringEncoding]];

            id value = [param objectForKey:paramsKey];
            if ([value isKindOfClass:[NSString class]]) {
                [body appendData:[value dataUsingEncoding:NSUTF8StringEncoding]];
            } else if ([value isKindOfClass:[NSData class]]) {
                [body appendData:value];
            }
            [body appendData:[@"\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
        }
    
        fileName = [InspurUtils formEscape:fileName];
    
        NSString *filePair = [NSString stringWithFormat:@"--%@\r\n%@; name=\"%@\"; filename=\"%@\"\nContent-Type:%@\r\n\r\n", boundary, disposition, @"file", fileName, self.uploadOption.mimeType];
        [body appendData:[filePair dataUsingEncoding:NSUTF8StringEncoding]];
    
        [body appendData:data];
        [body appendData:[[NSString stringWithFormat:@"\r\n--%@--\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    } @catch (NSException *exception) {
        if (complete) {
            InspurResponseInfo *info = [InspurResponseInfo responseInfoWithLocalIOError:[NSString stringWithFormat:@"%@", exception]];
            InspurUploadRegionRequestMetrics *metrics = [InspurUploadRegionRequestMetrics emptyMetrics];
            complete(info, metrics, nil);
        }
        return;
    }
    
    
    NSMutableDictionary *header = [NSMutableDictionary dictionary];
    header[@"Content-Type"] = [NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundary];
    header[@"Content-Length"] = [NSString stringWithFormat:@"%lu", (unsigned long)body.length];
    header[@"User-Agent"] = [kInspurUserAgent getUserAgent:self.token.token];
    
    BOOL (^shouldRetry)(InspurResponseInfo *, NSDictionary *) = ^(InspurResponseInfo * responseInfo, NSDictionary * response){
        return (BOOL)!responseInfo.isOK;
    };
    
    [self.regionRequest post:nil
                     headers:header
                        body:body
                 shouldRetry:shouldRetry
                    progress:progress
                    complete:complete];
}

//MARK: -- 分块上传
- (void)makeBlock:(long long)blockOffset
        blockSize:(long long)blockSize
   firstChunkData:(NSData *)firstChunkData
         progress:(void(^)(long long totalBytesWritten, long long totalBytesExpectedToWrite))progress
         complete:(InspurRequestTransactionCompleteHandler)complete{
    
    self.requestInfo.requestType = InspurUploadRequestTypeMkblk;
    self.requestInfo.fileOffset = @(blockOffset);
    
    NSString *token = [NSString stringWithFormat:@"UpToken %@", self.token.token];
    NSMutableDictionary *header = [NSMutableDictionary dictionary];
    header[@"Authorization"] = token;
    header[@"Content-Type"] = @"application/octet-stream";
    header[@"User-Agent"] = [kInspurUserAgent getUserAgent:self.token.token];
    
    NSString *action = [NSString stringWithFormat:@"/mkblk/%u", (unsigned int)blockSize];
    
    NSString *chunkCrc = [NSString stringWithFormat:@"%u", (unsigned int)[InspurCrc32 data:firstChunkData]];
    
    kInspurWeakSelf;
    BOOL (^shouldRetry)(InspurResponseInfo *, NSDictionary *) = ^(InspurResponseInfo * responseInfo, NSDictionary * response){
        kInspurStrongSelf;
        
        NSString *ctx = response[@"ctx"];
        NSString *crcServer = [NSString stringWithFormat:@"%@", response[@"crc32"]];
        return (BOOL)(responseInfo.isOK == false || (responseInfo.isOK && (!ctx || (self.uploadOption.checkCrc && ![chunkCrc isEqualToString:crcServer]))));
    };
    
    [self.regionRequest post:action
                     headers:header
                        body:firstChunkData
                 shouldRetry:shouldRetry
                    progress:progress
                    complete:complete];
}

- (void)uploadChunk:(NSString *)blockContext
        blockOffset:(long long)blockOffset
          chunkData:(NSData *)chunkData
        chunkOffset:(long long)chunkOffset
           progress:(void(^)(long long totalBytesWritten, long long totalBytesExpectedToWrite))progress
           complete:(InspurRequestTransactionCompleteHandler)complete{
    
    self.requestInfo.requestType = InspurUploadRequestTypeBput;
    self.requestInfo.fileOffset = @(blockOffset + chunkOffset);
    
    NSString *token = [NSString stringWithFormat:@"UpToken %@", self.token.token];
    NSMutableDictionary *header = [NSMutableDictionary dictionary];
    header[@"Authorization"] = token;
    header[@"Content-Type"] = @"application/octet-stream";
    header[@"User-Agent"] = [kInspurUserAgent getUserAgent:self.token.token];
    
    NSString *action = [NSString stringWithFormat:@"/bput/%@/%lld", blockContext,  chunkOffset];
    
    NSString *chunkCrc = [NSString stringWithFormat:@"%u", (unsigned int)[InspurCrc32 data:chunkData]];
    
    kInspurWeakSelf;
    BOOL (^shouldRetry)(InspurResponseInfo *, NSDictionary *) = ^(InspurResponseInfo * responseInfo, NSDictionary * response){
        kInspurStrongSelf;
        
        NSString *ctx = response[@"ctx"];
        NSString *crcServer = [NSString stringWithFormat:@"%@", response[@"crc32"]];
        return (BOOL)(responseInfo.isOK == false || (responseInfo.isOK && (!ctx || (self.uploadOption.checkCrc && ![chunkCrc isEqualToString:crcServer]))));
    };
    
    [self.regionRequest post:action
                     headers:header
                      body:chunkData
                 shouldRetry:shouldRetry
                    progress:progress
                    complete:complete];
}

- (void)makeFile:(long long)fileSize
        fileName:(NSString *)fileName
   blockContexts:(NSArray <NSString *> *)blockContexts
        complete:(InspurRequestTransactionCompleteHandler)complete{
    
    self.requestInfo.requestType = InspurUploadRequestTypeMkfile;
    
    NSString *token = [NSString stringWithFormat:@"UpToken %@", self.token.token];
    NSMutableDictionary *header = [NSMutableDictionary dictionary];
    header[@"Authorization"] = token;
    header[@"Content-Type"] = @"application/octet-stream";
    header[@"User-Agent"] = [kInspurUserAgent getUserAgent:self.token.token];
    
    NSString *mimeType = [[NSString alloc] initWithFormat:@"/mimeType/%@", [InspurUrlSafeBase64 encodeString:self.uploadOption.mimeType]];

    __block NSString *action = [[NSString alloc] initWithFormat:@"/mkfile/%lld%@", fileSize, mimeType];

    if (self.key != nil) {
        NSString *keyStr = [[NSString alloc] initWithFormat:@"/key/%@", [InspurUrlSafeBase64 encodeString:self.key]];
        action = [NSString stringWithFormat:@"%@%@", action, keyStr];
    }

    [self.uploadOption.params enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *obj, BOOL *stop) {
        action = [NSString stringWithFormat:@"%@/%@/%@", action, key, [InspurUrlSafeBase64 encodeString:obj]];
    }];
    
    [self.uploadOption.metaDataParam enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *obj, BOOL *stop) {
        action = [NSString stringWithFormat:@"%@/%@/%@", action, key, [InspurUrlSafeBase64 encodeString:obj]];
    }];

    //添加路径
    NSString *fname = [[NSString alloc] initWithFormat:@"/fname/%@", [InspurUrlSafeBase64 encodeString:fileName]];
    action = [NSString stringWithFormat:@"%@%@", action, fname];

    NSMutableData *body = [NSMutableData data];
    NSString *bodyString = [blockContexts componentsJoinedByString:@","];
    [body appendData:[bodyString dataUsingEncoding:NSUTF8StringEncoding]];
    
    BOOL (^shouldRetry)(InspurResponseInfo *, NSDictionary *) = ^(InspurResponseInfo * responseInfo, NSDictionary * response){
        return (BOOL)(!responseInfo.isOK);
    };
    
    [self.regionRequest post:action
                     headers:header
                        body:body
                 shouldRetry:shouldRetry
                    progress:nil
                    complete:complete];
}

- (void)initPart:(InspurRequestTransactionCompleteHandler)complete{
    
    self.requestInfo.requestType = InspurUploadRequestTypeInitParts;
    
    NSMutableString *action = [NSMutableString stringWithFormat:@"/%@", self.token.bucket];
    NSMutableDictionary *header = [NSMutableDictionary dictionary];
    [action appendFormat:@"/%@", [self.signatureContentGenerator safeKey]];
    [action appendFormat:@"?uploads&AccessKeyId=%@&Expires=%@", self.token.access, @(self.token.deadline)];
    if (!self.key) {
        //[action appendString:@"&random-object-name=true"];
    }
    
    NSString *contentNeedSignature = [self.signatureContentGenerator partInit];
    NSLog(@"contentNeedSignature:%@", contentNeedSignature);
    BOOL (^shouldRetry)(InspurResponseInfo *, NSDictionary *) = ^(InspurResponseInfo * responseInfo, NSDictionary * response){
        return (BOOL)(!responseInfo.isOK);
    };
    NSString *key = self.key;
    kInspurWeakSelf;
    self.token.signatureHandler(@[contentNeedSignature], ^(NSArray <NSString *> * _Nullable signaturedContents, NSError * _Nullable error) {
        kInspurStrongSelf;
        NSString *signature = [NSString stringWithFormat:@"%@", signaturedContents.count > 0 ? signaturedContents.firstObject : @""];
        [action appendFormat:@"&Signature=%@", signature ?: @""];
        if (!key) {
            [action appendString:@"&random-object-name=true"];
        }
        kInspurWeakSelf;
        [self.regionRequest post:action
                         headers:header
                            body:nil
                     shouldRetry:shouldRetry
                        progress:nil
                        complete:^(InspurResponseInfo * _Nullable responseInfo, InspurUploadRegionRequestMetrics * _Nullable metrics, NSDictionary * _Nullable response) {
            kInspurStrongSelf;
            [self updateKeyIfNeeded:responseInfo];
            complete(responseInfo, metrics, response);
        }];
    });
}
- (void)uploadPart:(NSString *)uploadId
         partIndex:(NSInteger)partIndex
          maxIndex:(NSInteger)maxPartNumber
          partData:(NSData *)partData
          progress:(void(^)(long long totalBytesWritten, long long totalBytesExpectedToWrite))progress
          complete:(InspurRequestTransactionCompleteHandler)complete{
    
    self.requestInfo.requestType = InspurUploadRequestTypeUploadPart;
    NSMutableDictionary *header = [NSMutableDictionary dictionary];
    NSString *partNumber = [[NSString alloc] initWithFormat:@"%ld", (long)partIndex];
    NSString *action = [NSString stringWithFormat:@"/%@/%@?partNumber=%@&uploadId=%@&AccessKeyId=%@&Expires=%@", self.token.bucket, [self.signatureContentGenerator safeKey], @(partIndex), uploadId, self.token.access, @(self.token.deadline)];
   
    BOOL (^shouldRetry)(InspurResponseInfo *, NSDictionary *) = ^(InspurResponseInfo * responseInfo, NSDictionary * response){
        //NSString *etag = [NSString stringWithFormat:@"%@", response[@"etag"]];
        //NSString *serverMD5 = [NSString stringWithFormat:@"%@", response[@"md5"]];
        //return (BOOL)(!responseInfo.isOK || !etag || !serverMD5);
        return (BOOL)(!responseInfo.isOK );
    };
    NSString *contentNeedSignature = [self.signatureContentGenerator partUpload:uploadId partIndex:partNumber];
    NSArray <NSString *>*contents = [self.signatureContentGenerator partUpload:uploadId partIndex:partIndex maxIndex:(int)maxPartNumber];
    NSString *cachedSignature = [self.signatureCache objectForKey:contentNeedSignature];
    
    if (cachedSignature.length > 0) {
        NSString *action1 = [NSString stringWithFormat:@"%@&Signature=%@", action, cachedSignature ?: @""];
        [self.regionRequest put:action1
                        headers:header
                           body:partData
                    shouldRetry:shouldRetry
                       progress:progress
                       complete:^(InspurResponseInfo * _Nullable responseInfo, InspurUploadRegionRequestMetrics * _Nullable metrics, NSDictionary * _Nullable response) {

            complete(responseInfo, metrics, response);
        }];
    } else {
        kInspurWeakSelf;
        self.token.signatureHandler(contents, ^(NSArray<NSString *> * _Nullable signaturedContents, NSError * _Nullable error) {
            kInspurStrongSelf;
            //缓存
            if (contents.count == signaturedContents.count && contents.count > 0) {
                for (int i = 0; i < contents.count; i++ ) {
                    NSString *content = [contents objectAtIndex:i];
                    NSString *signature = [signaturedContents objectAtIndex:i];
                    [self.signatureCache setValue:signature forKey:content];
                }
            }
            NSString *signature = [self.signatureCache objectForKey:contentNeedSignature];
            NSString *action1 = [NSString stringWithFormat:@"%@&Signature=%@", action, signature ?: @""];
            [self.regionRequest put:action1
                            headers:header
                               body:partData
                        shouldRetry:shouldRetry
                           progress:progress
                           complete:^(InspurResponseInfo * _Nullable responseInfo, InspurUploadRegionRequestMetrics * _Nullable metrics, NSDictionary * _Nullable response) {

                complete(responseInfo, metrics, response);
            }];
        });
    }
}

- (void)completeParts:(NSString *)fileName
             uploadId:(NSString *)uploadId
        partInfoArray:(NSArray <NSDictionary *> *)partInfoArray
             complete:(InspurRequestTransactionCompleteHandler)complete{
    
    self.requestInfo.requestType = InspurUploadRequestTypeCompletePart;
    
    if (!partInfoArray || partInfoArray.count == 0) {
        InspurResponseInfo *responseInfo = [InspurResponseInfo responseInfoWithInvalidArgument:@"partInfoArray"];
        if (complete) {
            complete(responseInfo, nil, responseInfo.responseDictionary);
        }
        return;
    }
    //NSString *token = [NSString stringWithFormat:@"UpToken %@", self.token.token];
    NSMutableDictionary *header = [NSMutableDictionary dictionary];
    //header[@"Authorization"] = token;
    header[@"Content-Type"] = @"text/plain";
    //header[@"User-Agent"] = [kInspurUserAgent getUserAgent:self.token.token];
    
    //NSString *buckets = [[NSString alloc] initWithFormat:@"/buckets/%@", self.token.bucket];
    //NSString *objects = [[NSString alloc] initWithFormat:@"/objects/%@", [self resumeV2EncodeKey:self.key]];
    //NSString *uploads = [[NSString alloc] initWithFormat:@"/uploads/%@", uploadId];
    NSLog(@"infoArray:%@", partInfoArray);
    
    NSString *action = [NSString stringWithFormat:@"/%@/%@?uploadId=%@&AccessKeyId=%@&Expires=%@", self.token.bucket, [self.signatureContentGenerator safeKey], uploadId, self.token.access, @(self.token.deadline)];

    NSMutableArray *array = [NSMutableArray array];
    for (NSDictionary *value in partInfoArray) {
        NSString *partNumber = [NSString stringWithFormat:@"%@", [value objectForKey:@"partNumber"]];
        NSString *ETag = [NSString stringWithFormat:@"%@", [value objectForKey:@"etag"]];
        [array addObject:[NSString stringWithFormat:@"<Part><PartNumber>%@</PartNumber><ETag>%@</ETag></Part>", partNumber, ETag]];
    }
    
    NSString *bodySting = [NSString stringWithFormat:@"<CompleteMultipartUpload>%@</CompleteMultipartUpload>", [array componentsJoinedByString:@""]];
    NSData *body = [bodySting dataUsingEncoding:NSUTF8StringEncoding];
    BOOL (^shouldRetry)(InspurResponseInfo *, NSDictionary *) = ^(InspurResponseInfo * responseInfo, NSDictionary * response){
        return (BOOL)(!responseInfo.isOK);
    };
    
    NSString *contentNeedSignatue = [self.signatureContentGenerator completeUpload:uploadId];
    kInspurWeakSelf;
    self.token.signatureHandler(@[contentNeedSignatue], ^(NSArray<NSString *> * _Nullable signaturedContents, NSError * _Nullable error) {
        kInspurStrongSelf;
        NSString *signature = [NSString stringWithFormat:@"%@", signaturedContents.count > 0 ? signaturedContents.firstObject : @""];
        NSString *action1 = [NSString stringWithFormat:@"%@&Signature=%@", action, signature ?: @""];
        [self.regionRequest post:action1
                         headers:header
                            body:body
                     shouldRetry:shouldRetry
                        progress:nil
                        complete:^(InspurResponseInfo * _Nullable responseInfo, InspurUploadRegionRequestMetrics * _Nullable metrics, NSDictionary * _Nullable response) {
            complete(responseInfo, metrics, response);
        }];
    });
}

- (void)reportLog:(NSData *)logData
      logClientId:(NSString *)logClientId
         complete:(InspurRequestTransactionCompleteHandler)complete {
    
    self.requestInfo.requestType = InspurUploadRequestTypeUpLog;
    NSString *token = [NSString stringWithFormat:@"UpToken %@", self.token.token];
    NSMutableDictionary *header = [NSMutableDictionary dictionary];
    header[@"Authorization"] = token;
    header[@"Content-Type"] = @"application/json";
    header[@"User-Agent"] = [kInspurUserAgent getUserAgent:self.token.token];
    
    NSString *action = @"/log/4?compressed=gzip";
    
    if (logClientId) {
        header[@"X-Log-Client-Id"] = logClientId;
    }
    
    BOOL (^shouldRetry)(InspurResponseInfo *, NSDictionary *) = ^(InspurResponseInfo * responseInfo, NSDictionary * response){
        return (BOOL)(!responseInfo.isOK);
    };
    
    [self.regionRequest post:action
                     headers:header
                        body:logData
                 shouldRetry:shouldRetry
                    progress:nil
                    complete:^(InspurResponseInfo * _Nullable responseInfo, InspurUploadRegionRequestMetrics * _Nullable metrics, NSDictionary * _Nullable response) {

        complete(responseInfo, metrics, response);
    }];
}

- (void)serverConfig:(InspurRequestTransactionCompleteHandler)complete {
    
    self.requestInfo.requestType = InspurUploadRequestTypeServerConfig;
    NSMutableDictionary *header = [NSMutableDictionary dictionary];
    header[@"User-Agent"] = [kInspurUserAgent getUserAgent:self.token.token];
    
    NSString *action = [NSString stringWithFormat:@"/v1/sdk/config?sdk_name=%@&sdk_version=%@", [InspurUtils sdkLanguage], [InspurUtils sdkVersion]];
    
    BOOL (^shouldRetry)(InspurResponseInfo *, NSDictionary *) = ^(InspurResponseInfo * responseInfo, NSDictionary * response){
        return (BOOL)(!responseInfo.isOK);
    };
    
    [self.regionRequest post:action
                     headers:header
                        body:nil
                 shouldRetry:shouldRetry
                    progress:nil
                    complete:^(InspurResponseInfo * _Nullable responseInfo, InspurUploadRegionRequestMetrics * _Nullable metrics, NSDictionary * _Nullable response) {

        complete(responseInfo, metrics, response);
    }];
}

- (void)serverUserConfig:(InspurRequestTransactionCompleteHandler)complete {
    
    self.requestInfo.requestType = InspurUploadRequestTypeServerUserConfig;
    NSMutableDictionary *header = [NSMutableDictionary dictionary];
    header[@"User-Agent"] = [kInspurUserAgent getUserAgent:self.token.token];
    
    NSString *action = [NSString stringWithFormat:@"/v1/sdk/config/user?ak=%@&sdk_name=%@&sdk_version=%@", self.token.access, [InspurUtils sdkLanguage], [InspurUtils sdkVersion]];
    
    BOOL (^shouldRetry)(InspurResponseInfo *, NSDictionary *) = ^(InspurResponseInfo * responseInfo, NSDictionary * response){
        return (BOOL)(!responseInfo.isOK);
    };
    
    [self.regionRequest post:action
                     headers:header
                        body:nil
                 shouldRetry:shouldRetry
                    progress:nil
                    complete:^(InspurResponseInfo * _Nullable responseInfo, InspurUploadRegionRequestMetrics * _Nullable metrics, NSDictionary * _Nullable response) {

        complete(responseInfo, metrics, response);
    }];
}

- (void)updateKeyIfNeeded:(InspurResponseInfo *)responseInfo {
    NSString *key = self.key;
    NSString *objectName = responseInfo.responseHeader[@"object-name"];
    if (!key && objectName.length > 0) {
        _key = objectName;
        [self.signatureContentGenerator updateKey:objectName];
    }
}


- (NSString *)resumeV2EncodeKey:(NSString *)key{
    NSString *encodeKey = nil;
    if (!self.key) {
        encodeKey = @"~";
    } else if (self.key.length == 0) {
        encodeKey = @"";
    } else {
        encodeKey = [InspurUrlSafeBase64 encodeString:self.key];
    }
    return encodeKey;
}

@end
