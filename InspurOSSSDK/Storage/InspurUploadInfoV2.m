//
//  InspurUploadInfoV2.m
//  InspurOSSSDK
//
//  Created by Brook on 2021/5/13.
//  Copyright © 2021 Inspur. All rights reserved.
//

#import "NSData+InspurMD5.h"
#import "InspurMutableArray.h"
#import "InspurUploadInfoV2.h"

#define kTypeValue @"UploadInfoV2"
#define kMaxDataSize (1024 * 1024 * 1024)

@interface InspurUploadInfoV2()

@property(nonatomic, assign)int dataSize;
@property(nonatomic, strong)InspurMutableArray *dataList;

@property(nonatomic, assign)BOOL isEOF;
@property(nonatomic, strong, nullable)NSError *readError;
@end
@implementation InspurUploadInfoV2

+ (instancetype)info:(id<InspurUploadSource>)source
       configuration:(nonnull InspurConfiguration *)configuration {
    
    InspurUploadInfoV2 *info = [InspurUploadInfoV2 info:source];
    info.dataSize = MIN(configuration.chunkSize, kMaxDataSize);
    info.dataList = [InspurMutableArray array];
    return info;
}

+ (instancetype)info:(id <InspurUploadSource>)source
          dictionary:(NSDictionary *)dictionary {
    if (dictionary == nil) {
        return nil;
    }
    
    int dataSize = [dictionary[@"dataSize"] intValue];
    NSNumber *expireAt = dictionary[@"expireAt"];
    NSString *uploadId = dictionary[@"uploadId"];
    NSString *type = dictionary[kInspurUploadInfoTypeKey];
    if (expireAt == nil || ![expireAt isKindOfClass:[NSNumber class]] ||
        uploadId == nil || ![uploadId isKindOfClass:[NSString class]] || uploadId.length == 0) {
        return nil;
    }
    
    NSArray *dataInfoList = dictionary[@"dataList"];
    
    InspurMutableArray *dataList = [InspurMutableArray array];
    if ([dataInfoList isKindOfClass:[NSArray class]]) {
        for (int i = 0; i < dataInfoList.count; i++) {
            NSDictionary *dataInfo = dataInfoList[i];
            if ([dataInfo isKindOfClass:[NSDictionary class]]) {
                InspurUploadData *data = [InspurUploadData dataFromDictionary:dataInfo];
                if (data == nil) {
                    return nil;
                }
                [dataList addObject:data];
            }
        }
    }
    
    InspurUploadInfoV2 *info = [InspurUploadInfoV2 info:source];
    [info setInfoFromDictionary:dictionary];
    info.expireAt = expireAt;
    info.uploadId = uploadId;
    info.dataSize = dataSize;
    info.dataList = dataList;
    
    if (![type isEqualToString:kTypeValue] || ![[source getId] isEqualToString:[info getSourceId]]) {
        return nil;
    } else {
        return info;
    }
}

- (BOOL)isValid {
    if (![super isValid]) {
        return false;
    }
    
    if (!self.expireAt || !self.uploadId || self.uploadId.length == 0) {
        return false;
    }
    
    return (self.expireAt.doubleValue - 2*3600) > [[NSDate date] timeIntervalSince1970];
}

- (BOOL)reloadSource {
    self.isEOF = false;
    self.readError = nil;
    return [super reloadSource];
}

- (BOOL)isSameUploadInfo:(InspurUploadInfo *)info {
    if (![super isSameUploadInfo:info]) {
        return false;
    }
    
    if (![info isKindOfClass:[InspurUploadInfoV2 class]]) {
        return false;
    }
    
    return self.dataSize == [(InspurUploadInfoV2 *)info dataSize];
}

- (void)clearUploadState {
    self.expireAt = nil;
    self.uploadId = nil;
    if (self.dataList == nil || self.dataList.count == 0) {
        return;
    }
    
    [self.dataList enumerateObjectsUsingBlock:^(InspurUploadData *data, NSUInteger idx, BOOL * _Nonnull stop) {
        [data clearUploadState];
    }];
}

- (void)checkInfoStateAndUpdate {
    [self.dataList enumerateObjectsUsingBlock:^(InspurUploadData *data, NSUInteger idx, BOOL * _Nonnull stop) {
        [data checkStateAndUpdate];
    }];
}

- (long long)uploadSize {
    if (self.dataList == nil || self.dataList.count == 0) {
        return 0;
    }
    
    __block long long uploadSize = 0;
    [self.dataList enumerateObjectsUsingBlock:^(InspurUploadData *data, NSUInteger idx, BOOL * _Nonnull stop) {
        uploadSize += [data uploadSize];
    }];
    return uploadSize;
}

- (BOOL)isAllUploaded {
    if (!_isEOF) {
        return false;
    }
    
    if (self.dataList == nil || self.dataList.count == 0) {
        return true;
    }
    
    __block BOOL isAllUploaded = true;
    [self.dataList enumerateObjectsUsingBlock:^(InspurUploadData *data, NSUInteger idx, BOOL * _Nonnull stop) {
        if (!data.isUploaded) {
            isAllUploaded = false;
            *stop = true;
        }
    }];
    return isAllUploaded;
}

- (NSDictionary *)toDictionary {
    NSMutableDictionary *dictionary = [[super toDictionary] mutableCopy];
    if (dictionary == nil) {
        dictionary = [NSMutableDictionary dictionary];
    }
    [dictionary setObject:kTypeValue forKey:kInspurUploadInfoTypeKey];
    [dictionary setObject:@(self.dataSize) forKey:@"dataSize"];
    [dictionary setObject:self.expireAt ?: 0 forKey:@"expireAt"];
    [dictionary setObject:self.uploadId ?: @"" forKey:@"uploadId"];
    
    if (self.dataList != nil && self.dataList.count != 0) {
        NSMutableArray *blockInfoList = [NSMutableArray array];
        [self.dataList enumerateObjectsUsingBlock:^(InspurUploadData *data, NSUInteger idx, BOOL * _Nonnull stop) {
            [blockInfoList addObject:[data toDictionary]];
        }];
        [dictionary setObject:[blockInfoList copy] forKey:@"dataList"];
    }
    
    return [dictionary copy];
}

- (NSInteger)getPartIndexOfData:(InspurUploadData *)data {
    return data.index + 1;
}

- (InspurUploadData *)nextUploadData:(NSError **)error {
    
    // 从 dataList 中读取需要上传的 data
    InspurUploadData *data = [self nextUploadDataFormDataList];
    
    // 内存的 dataList 中没有可上传的数据，则从资源中读并创建 data
    if (data == nil) {
        if (self.isEOF) {
            return nil;
        } else if (self.readError) {
            *error = self.readError;
            return nil;
        }
        
        // 从资源中读取新的 block 进行上传
        long long dataOffset = 0;
        if (self.dataList.count > 0) {
            InspurUploadData *lastData = self.dataList[self.dataList.count - 1];
            dataOffset = lastData.offset + lastData.size;
        }
        
        data = [[InspurUploadData alloc] initWithOffset:dataOffset dataSize:self.dataSize index:self.dataList.count];
    }
    
    InspurUploadData*loadData = [self loadData:data error:error];
    if (*error != nil) {
        self.readError = *error;
        return nil;
    }
    
    if (loadData == nil) {
        // 没有加在到 data, 也即数据源读取结束
        self.isEOF = true;
        // 有多余的 data 则移除，移除中包含 data
        if (self.dataList.count > data.index) {
            self.dataList = [[self.dataList subarrayWithRange:NSMakeRange(0, data.index)] mutableCopy];
        }
    } else {
        // 加在到 data
        if (loadData.index == self.dataList.count) {
            // 新块：data index 等于 dataList size 则为新创建 block，需要加入 dataList
            [self.dataList addObject:loadData];
        } else if (loadData != data) {
            // 更换块：重新加在了 data， 更换信息
            [self.dataList replaceObjectAtIndex:loadData.index withObject:loadData];
        }
        
        // 数据源读取结束，块读取大小小于预期，读取结束
        if (loadData.size < data.size) {
            self.isEOF = true;
            // 有多余的 data 则移除，移除中不包含 data
            if (self.dataList.count > data.index + 1) {
                self.dataList = [[self.dataList subarrayWithRange:NSMakeRange(0, data.index + 1)] mutableCopy];
            }
        }
    }
    
    return loadData;
}

- (InspurUploadData *)nextUploadDataFormDataList {
    if (self.dataList == nil || self.dataList.count == 0) {
        return nil;
    }
    
    __block InspurUploadData *data = nil;
    [self.dataList enumerateObjectsUsingBlock:^(InspurUploadData *dataP, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([dataP needToUpload]) {
            data = dataP;
            *stop = true;
        }
    }];
    
    return data;
}

// 加载块中的数据
// 1. 数据块已加载，直接返回
// 2. 数据块未加载，读块数据
// 2.1 如果未读到数据，则已 EOF，返回 null
// 2.2 如果读到数据
// 2.2.1 如果块数据符合预期，则当片未上传，则加载片数据
// 2.2.2 如果块数据不符合预期，创建新块，加载片信息
- (InspurUploadData *)loadData:(InspurUploadData *)data error:(NSError **)error {
    if (data == nil) {
        return nil;
    }
    
    // 之前已加载并验证过数据，不必在验证
    if (data.data != nil) {
        return data;
    }
    
    // 未加载过 block 数据
    // 根据 data 信息加载 dataBytes
    NSData *dataBytes = [self readData:(NSInteger)data.size dataOffset:data.offset error:error];
    if (*error != nil) {
        return nil;
    }

    // 没有数据不需要上传
    if (dataBytes == nil || dataBytes.length == 0) {
        return nil;
    }

    NSString *md5 = [dataBytes qn_md5];
    // 判断当前 block 的数据是否和实际数据吻合，不吻合则之前 block 被抛弃，重新创建 block
    if (dataBytes.length != data.size || data.md5 == nil || ![data.md5 isEqualToString:md5]) {
        data = [[InspurUploadData alloc] initWithOffset:data.offset dataSize:dataBytes.length index:data.index];
        data.md5 = md5;
    }

    if (data.etag == nil || data.etag.length == 0) {
        data.data = dataBytes;
        data.state = QNUploadStateWaitToUpload;
    } else {
        data.state = QNUploadStateComplete;
    }

    return data;
}

- (NSArray <NSDictionary <NSString *, NSObject *> *> *)getPartInfoArray {
    if (self.uploadId == nil || self.uploadId.length == 0) {
        return nil;
    }
    
    NSMutableArray *infoArray = [NSMutableArray array];
    [self.dataList enumerateObjectsUsingBlock:^(InspurUploadData *data, NSUInteger idx, BOOL * _Nonnull stop) {
        if (data.state == QNUploadStateComplete && data.etag != nil) {
            [infoArray addObject:@{@"etag" : data.etag,
                                   @"partNumber" : @([self getPartIndexOfData:data])}];
        }
    }];
    
    return [infoArray copy];
}

@end
