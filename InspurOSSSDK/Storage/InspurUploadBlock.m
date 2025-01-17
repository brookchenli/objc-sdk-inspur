//
//  InspurUploadBlock.m
//  InspurOSSSDK
//
//  Created by Brook on 2021/5/10.
//  Copyright © 2021 Inspur. All rights reserved.
//

#import "InspurUploadBlock.h"

@interface InspurUploadBlock()

@property(nonatomic, assign)long long offset;
@property(nonatomic, assign)NSInteger size;
@property(nonatomic, assign)NSInteger index;
@property(nonatomic, strong)NSArray <InspurUploadData *> *uploadDataList;

@end
@implementation InspurUploadBlock

+ (instancetype)blockFromDictionary:(NSDictionary *)dictionary{
    if (![dictionary isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
         
    InspurUploadBlock *block = [[InspurUploadBlock alloc] init];
    block.offset = [dictionary[@"offset"] longLongValue];
    block.size = [dictionary[@"size"] integerValue];
    block.index = [dictionary[@"index"] integerValue];
    block.expiredAt = dictionary[@"expired_at"];
    block.md5 = dictionary[@"md5"];
    block.context = dictionary[@"context"];
    
    NSArray *uploadDataInfos = dictionary[@"uploadDataList"];
    if ([uploadDataInfos isKindOfClass:[NSArray class]]) {
        
        NSMutableArray *uploadDataList = [NSMutableArray array];
        for (NSDictionary *uploadDataInfo in uploadDataInfos) {
            InspurUploadData *data = [InspurUploadData dataFromDictionary:uploadDataInfo];
            if (!data) {
                return nil;
            }
            [uploadDataList addObject:data];
        }
        block.uploadDataList = [uploadDataList copy];
    }
    return block;
}

- (instancetype)initWithOffset:(long long)offset
                     blockSize:(NSInteger)blockSize
                      dataSize:(NSInteger)dataSize
                         index:(NSInteger)index {
    if (self = [super init]) {
        _offset = offset;
        _size = blockSize;
        _index = index;
        _uploadDataList = [self createDataList:dataSize];
    }
    return self;
}

- (BOOL)isValid {
    if (!self.expiredAt || self.expiredAt.integerValue <= 0) {
        // 不存在时，为新创建 block: 有效
        return true;
    }
    
    // 存在则有效期必须为过期
    return (self.expiredAt.doubleValue - 2*3600) > [[NSDate date] timeIntervalSince1970];
}

- (BOOL)isCompleted{
    if (self.uploadDataList == nil) {
        return true;
    }
    
    BOOL isCompleted = true;
    for (InspurUploadData *data in self.uploadDataList) {
        if (data.isUploaded == false) {
            isCompleted = false;
            break;
        }
    }
    return isCompleted;
}

- (NSInteger)uploadSize {
    if (self.uploadDataList == nil) {
        return 0;
    }

    NSInteger uploadSize = 0;
    for (InspurUploadData *data in self.uploadDataList) {
        uploadSize += data.uploadSize;
    }
    return uploadSize;
}

- (NSArray *)createDataList:(long long)dataSize{
    
    long long offSize = 0;
    NSInteger dataIndex = 0;
    NSMutableArray *datas = [NSMutableArray array];
    while (offSize < self.size) {
        long long lastSize = self.size - offSize;
        long long dataSizeP = MIN(lastSize, dataSize);
        InspurUploadData *data = [[InspurUploadData alloc] initWithOffset:offSize
                                                         dataSize:dataSizeP
                                                            index:dataIndex];
        [datas addObject:data];
        offSize += dataSizeP;
        dataIndex += 1;
    }
    return [datas copy];
}

- (InspurUploadData *)nextUploadDataWithoutCheckData {
    if (!self.uploadDataList || self.uploadDataList.count == 0) {
        return nil;
    }
    
    InspurUploadData *data = nil;
    for (InspurUploadData *dataP in self.uploadDataList) {
        if ([dataP needToUpload]) {
            data = dataP;
            break;
        }
    }
    return data;
}

- (void)clearUploadState{
    self.md5 = nil;
    self.context = nil;
    for (InspurUploadData *data in self.uploadDataList) {
        [data clearUploadState];
    }
}

- (void)checkInfoStateAndUpdate {
    for (InspurUploadData *data in self.uploadDataList) {
        [data checkStateAndUpdate];
    }
}

- (NSDictionary *)toDictionary{
    
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    dictionary[@"offset"]      = @(self.offset);
    dictionary[@"size"]        = @(self.size);
    dictionary[@"index"]       = @(self.index);
    dictionary[@"expired_at"]  = self.expiredAt ?: @(0);
    dictionary[@"md5"]         = self.md5 ?: @"";
    if (self.context) {
        dictionary[@"context"] = self.context;
    }

    if (self.uploadDataList) {
        
        NSMutableArray *uploadDataInfos = [NSMutableArray array];
        for (InspurUploadData *data in self.uploadDataList) {
            
            NSDictionary *uploadDataInfo = [data toDictionary];
            if (uploadDataInfo) {
                [uploadDataInfos addObject:uploadDataInfo];
            }
        }
        dictionary[@"uploadDataList"]  = [uploadDataInfos copy];
    }
    
    return [dictionary copy];
}

@end
