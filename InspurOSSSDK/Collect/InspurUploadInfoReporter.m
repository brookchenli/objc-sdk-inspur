//
//  InspurUploadInfoReporter.m
//  InspurOSSSDK
//
//  Created by WorkSpace_Sun on 2019/6/24.
//  Copyright © 2019 Inspur. All rights reserved.
//
#import "InspurDefine.h"
#import "InspurZoneInfo.h"
#import "InspurUploadInfoReporter.h"
#import "InspurResponseInfo.h"
#import "InspurUtils.h"
#import "InspurFile.h"
#import "InspurUpToken.h"
#import "InspurUserAgent.h"
#import "InspurAsyncRun.h"
#import "InspurVersion.h"
#import "InspurReportConfig.h"
#import "NSData+InspurGZip.h"
#import "InspurTransactionManager.h"
#import "InspurRequestTransaction.h"

#define kInspurUplogDelayReportTransactionName @"com.qiniu.uplog"

@interface InspurUploadInfoReporter ()

@property (nonatomic, strong) InspurReportConfig *config;
@property (nonatomic, assign) NSTimeInterval lastReportTime;
@property (nonatomic, strong) NSString *recorderFilePath;
@property (nonatomic, strong) NSString *recorderTempFilePath;
@property (nonatomic, copy) NSString *X_Log_Client_Id;

@property (nonatomic, strong) InspurRequestTransaction *transaction;
@property (nonatomic, assign) BOOL isReporting;

@property (nonatomic, strong) dispatch_queue_t recordQueue;
@property (nonatomic, strong) dispatch_semaphore_t semaphore;
@end

@implementation InspurUploadInfoReporter

+ (instancetype)sharedInstance {
    
    static InspurUploadInfoReporter *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    
    self = [super init];
    if (self) {
        _config = [InspurReportConfig sharedInstance];
        _lastReportTime = 0;
        _recorderFilePath = [NSString stringWithFormat:@"%@/%@", _config.recordDirectory, @"qiniu.log"];
        _recorderTempFilePath = [NSString stringWithFormat:@"%@/%@", _config.recordDirectory, @"qiniuTemp.log"];
        _recordQueue = dispatch_queue_create("com.qiniu.reporter", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (void)clean {
    [self cleanRecorderFile];
    [self cleanTempRecorderFile];
}

- (void)cleanRecorderFile {
    NSFileManager *manager = [NSFileManager defaultManager];
    if ([manager fileExistsAtPath:_recorderFilePath]) {
        NSError *error = nil;
        [manager removeItemAtPath:_recorderFilePath error:&error];
        if (error) {
            NSLog(@"remove recorder file failed: %@", error);
            return;
        }
    }
}

- (void)cleanTempRecorderFile {
    NSFileManager *manager = [NSFileManager defaultManager];
    if ([manager fileExistsAtPath:_recorderTempFilePath]) {
        NSError *error = nil;
        [manager removeItemAtPath:_recorderTempFilePath error:&error];
        if (error) {
            NSLog(@"remove recorder temp file failed: %@", error);
            return;
        }
    }
}

- (BOOL)checkReportAvailable {
    if (!_config.isReportEnable) {
        return NO;
    }
    if (_config.maxRecordFileSize <= _config.uploadThreshold) {
        NSLog(@"maxRecordFileSize must be larger than uploadThreshold");
        return NO;
    }
    return YES;
}

- (void)report:(NSString *)jsonString token:(NSString *)token {
    
    if (![self checkReportAvailable] || !jsonString || !token || token.length == 0) {
        return;
    }
    
    // 串行队列处理文件读写
    dispatch_async(_recordQueue, ^{
        [self saveReportJsonString:jsonString];
        [self reportToServerIfNeeded:token];
    });
}

- (void)saveReportJsonString:(NSString *)jsonString {
    NSString *finalRecordInfo = [jsonString stringByAppendingString:@"\n"];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:self.recorderFilePath]) {
        // 如果recordFile不存在，创建文件并写入首行，首次不上传
        [finalRecordInfo writeToFile:_recorderFilePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    } else {
        NSDictionary *recorderFileAttr = [fileManager attributesOfItemAtPath:self.recorderFilePath error:nil];
        if ([recorderFileAttr fileSize] > self.config.maxRecordFileSize) {
            return;
        }
        
        NSFileHandle *fileHandler = nil;
        @try {
            // 上传信息写入recorder文件
            fileHandler = [NSFileHandle fileHandleForUpdatingAtPath:_recorderFilePath];
            [fileHandler seekToEndOfFile];
            [fileHandler writeData: [finalRecordInfo dataUsingEncoding:NSUTF8StringEncoding]];
        } @catch (NSException *exception) {
            NSLog(@"NSFileHandle cannot write data: %@", exception.description);
        } @finally {
            [fileHandler closeFile];
        }
    }
}

- (void)reportToServerIfNeeded:(NSString *)tokenString {
    BOOL needToReport = NO;
    long currentTime = [[NSDate date] timeIntervalSince1970];
    long interval = self.config.interval * 10;
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSDictionary *recorderFileAttr = [fileManager attributesOfItemAtPath:self.recorderFilePath error:nil];
    if ([fileManager fileExistsAtPath:self.recorderTempFilePath]) {
        needToReport = YES;
    } else if ((self.lastReportTime == 0 || (currentTime - self.lastReportTime) >= interval || [recorderFileAttr fileSize] > self.config.uploadThreshold) &&
            ([fileManager moveItemAtPath:self.recorderFilePath toPath:self.recorderTempFilePath error:nil])) {
        needToReport = YES;
    }
    
    if (needToReport && !self.isReporting) {
        [self reportToServer:tokenString];
    } else {
        // 有未上传日志存在，则 interval 时间后再次重试一次
        if (![fileManager fileExistsAtPath:self.recorderFilePath] || [recorderFileAttr fileSize] == 0) {
            return;
        }
        
        NSArray *transactionList = [kInspurTransactionManager transactionsForName:kInspurUplogDelayReportTransactionName];
        if (transactionList != nil && transactionList.count > 1) {
            return;
        }

        if (transactionList != nil && transactionList.count == 1) {
            InspurTransaction *transaction = transactionList.firstObject;
            if (transaction != nil && !transaction.isExecuting) {
                return;
            }
        }
        
        InspurTransaction *transaction = [InspurTransaction transaction:kInspurUplogDelayReportTransactionName after:interval action:^{
            [self reportToServerIfNeeded:tokenString];
        }];
        [kInspurTransactionManager addTransaction:transaction];
    }
}


- (void)reportToServer:(NSString *)tokenString {
    if (tokenString == nil) {
        return;
    }
    InspurUpToken *token = [InspurUpToken parse:tokenString];
    if (!token.isValid) {
        return;
    }
    
    NSData *logData = [self getLogData];
    if (logData == nil) {
        return;
    }
    
    self.isReporting = YES;
    logData = [NSData inspur_gZip:logData];
    InspurRequestTransaction *transaction = [self createUploadRequestTransaction:token];
    [transaction reportLog:logData logClientId:self.X_Log_Client_Id complete:^(InspurResponseInfo * _Nullable responseInfo, InspurUploadRegionRequestMetrics * _Nullable metrics, NSDictionary * _Nullable response) {
        if (responseInfo.isOK) {
            self.lastReportTime = [[NSDate dateWithTimeIntervalSinceNow:0] timeIntervalSince1970];
            if (!self.X_Log_Client_Id) {
                self.X_Log_Client_Id = responseInfo.responseHeader[@"x-log-client-id"];
            }
            [self cleanTempRecorderFile];
        } else {
            NSLog(@"upload info report failed: %@", responseInfo);
        }
        
        self.isReporting = NO;
        [self destroyUploadRequestTransaction:transaction];
    }];
}

- (NSData *)getLogData {
    return [NSData dataWithContentsOfFile:_recorderTempFilePath];
}

- (InspurRequestTransaction *)createUploadRequestTransaction:(InspurUpToken *)token{
    if (self.config.serverURL) {
        
    }
    NSArray *hosts = nil;
    if (self.config.serverHost) {
        hosts = @[self.config.serverHost];
    }
    InspurRequestTransaction *transaction = [[InspurRequestTransaction alloc] initWithHosts:hosts
                                                                           regionId:InspurZoneInfoEmptyRegionId
                                                                              token:token];
    self.transaction = transaction;
    return transaction;
}

- (void)destroyUploadRequestTransaction:(InspurRequestTransaction *)transaction{
    self.transaction = nil;
}

@end
