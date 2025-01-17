//
//  InspurUploadInfoV1.m
//  InspurOSSSDK
//
//  Created by Brook on 2021/5/10.
//  Copyright © 2021 Inspur. All rights reserved.
//

#import "NSData+InspurMD5.h"
#import "InspurMutableArray.h"
#import "InspurUploadInfoV1.h"

#define kTypeValue @"UploadInfoV1"
#define kBlockSize (8 * 1024 * 1024)

@interface InspurUploadInfoV1()

@property(nonatomic, assign)int dataSize;
@property(nonatomic, strong)InspurMutableArray *blockList;

@property(nonatomic, assign)BOOL isEOF;
@property(nonatomic, strong, nullable)NSError *readError;
@end
@implementation InspurUploadInfoV1

+ (instancetype)info:(id<InspurUploadSource>)source
       configuration:(nonnull InspurConfiguration *)configuration {
    
    InspurUploadInfoV1 *info = [InspurUploadInfoV1 info:source];
    if (configuration.useConcurrentResumeUpload || configuration.chunkSize > kBlockSize) {
        info.dataSize = kBlockSize;
    } else {
        info.dataSize = configuration.chunkSize;
    }
    info.blockList = [InspurMutableArray array];
    return info;
}

+ (instancetype)info:(id <InspurUploadSource>)source
          dictionary:(NSDictionary *)dictionary {
    if (dictionary == nil) {
        return nil;
    }
    
    int dataSize = [dictionary[@"dataSize"] intValue];
    NSString *type = dictionary[kInspurUploadInfoTypeKey];
    NSArray *blockInfoList = dictionary[@"blockList"];
    
    InspurMutableArray *blockList = [InspurMutableArray array];
    if ([blockInfoList isKindOfClass:[NSArray class]]) {
        for (int i = 0; i < blockInfoList.count; i++) {
            NSDictionary *blockInfo = blockInfoList[i];
            if ([blockInfo isKindOfClass:[NSDictionary class]]) {
                InspurUploadBlock *block = [InspurUploadBlock blockFromDictionary:blockInfo];
                if (block == nil) {
                    return nil;
                }
                [blockList addObject:block];
            }
        }
    }
    
    InspurUploadInfoV1 *info = [InspurUploadInfoV1 info:source];
    [info setInfoFromDictionary:dictionary];
    info.dataSize = dataSize;
    info.blockList = blockList;
    
    if (![type isEqualToString:kTypeValue] || ![[source getId] isEqualToString:[info getSourceId]]) {
        return nil;
    } else {
        return info;
    }
}

- (BOOL)isFirstData:(InspurUploadData *)data {
    return data.index == 0;
}

- (BOOL)isValid {
    if (![super isValid]) {
        return false;
    }
    
    __block BOOL valid = true;
    [self.blockList enumerateObjectsUsingBlock:^(InspurUploadBlock *block, NSUInteger idx, BOOL * _Nonnull stop) {
        valid = [block isValid];
        if (!valid) {
            *stop = true;
        }
    }];
    return  valid;
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
    
    if (![info isKindOfClass:[InspurUploadInfoV1 class]]) {
        return false;
    }
    
    return self.dataSize == [(InspurUploadInfoV1 *)info dataSize];
}

- (void)clearUploadState {
    if (self.blockList == nil || self.blockList.count == 0) {
        return;
    }
    
    [self.blockList enumerateObjectsUsingBlock:^(InspurUploadBlock *block, NSUInteger idx, BOOL * _Nonnull stop) {
        [block clearUploadState];
    }];
}

- (void)checkInfoStateAndUpdate {
    [self.blockList enumerateObjectsUsingBlock:^(InspurUploadBlock *block, NSUInteger idx, BOOL * _Nonnull stop) {
        [block checkInfoStateAndUpdate];
    }];
}

- (long long)uploadSize {
    if (self.blockList == nil || self.blockList.count == 0) {
        return 0;
    }
    
    __block long long uploadSize = 0;
    [self.blockList enumerateObjectsUsingBlock:^(InspurUploadBlock *block, NSUInteger idx, BOOL * _Nonnull stop) {
        uploadSize += [block uploadSize];
    }];
    return uploadSize;
}

- (BOOL)isAllUploaded {
    if (!_isEOF) {
        return false;
    }
    
    if (self.blockList == nil || self.blockList.count == 0) {
        return true;
    }
    
    __block BOOL isAllUploaded = true;
    [self.blockList enumerateObjectsUsingBlock:^(InspurUploadBlock *block, NSUInteger idx, BOOL * _Nonnull stop) {
        if (!block.isCompleted) {
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
    
    if (self.blockList != nil && self.blockList.count != 0) {
        NSMutableArray *blockInfoList = [NSMutableArray array];
        [self.blockList enumerateObjectsUsingBlock:^(InspurUploadBlock *block, NSUInteger idx, BOOL * _Nonnull stop) {
            [blockInfoList addObject:[block toDictionary]];
        }];
        [dictionary setObject:[blockInfoList copy] forKey:@"blockList"];
    }
    
    return [dictionary copy];
}

- (InspurUploadBlock *)nextUploadBlock:(NSError **)error {
    // 从 blockList 中读取需要上传的 block
    InspurUploadBlock *block = [self nextUploadBlockFormBlockList];
    
    // 内存的 blockList 中没有可上传的数据，则从资源中读并创建 block
    if (block == nil) {
        if (self.isEOF) {
            return nil;
        } else if (self.readError) {
            *error = self.readError;
            return nil;
        }
        
        // 从资源中读取新的 block 进行上传
        long long blockOffset = 0;
        if (self.blockList.count > 0) {
            InspurUploadBlock *lastBlock = self.blockList[self.blockList.count - 1];
            blockOffset = lastBlock.offset + (long long)(lastBlock.size);
        }

        block = [[InspurUploadBlock alloc] initWithOffset:blockOffset blockSize:kBlockSize dataSize:self.dataSize index:self.blockList.count];
    }
    
    InspurUploadBlock *loadBlock = [self loadBlockData:block error:error];
    if (*error != nil) {
        self.readError = *error;
        return nil;
    }
    
    if (loadBlock == nil) {
        // 没有加在到 block, 也即数据源读取结束
        self.isEOF = true;
        // 有多余的 block 则移除，移除中包含 block
        if (self.blockList.count > block.index) {
            self.blockList = [[self.blockList subarrayWithRange:NSMakeRange(0, block.index)] mutableCopy];
        }
    } else {
        // 加在到 block
        if (loadBlock.index == self.blockList.count) {
            // 新块：block index 等于 blockList size 则为新创建 block，需要加入 blockList
            [self.blockList addObject:loadBlock];
        } else if (loadBlock != block) {
            // 更换块：重新加在了 block， 更换信息
            [self.blockList replaceObjectAtIndex:loadBlock.index withObject:loadBlock];
        }
        
        // 数据源读取结束，块读取大小小于预期，读取结束
        if (loadBlock.size < kBlockSize) {
            self.isEOF = true;
            // 有多余的 block 则移除，移除中不包含 block
            if (self.blockList.count > block.index + 1) {
                self.blockList = [[self.blockList subarrayWithRange:NSMakeRange(0, block.index + 1)] mutableCopy];
            }
        }
    }
    
    return loadBlock;
}

- (InspurUploadBlock *)nextUploadBlockFormBlockList {
    if (self.blockList == nil || self.blockList.count == 0) {
        return nil;
    }
    
    __block InspurUploadBlock *block = nil;
    [self.blockList enumerateObjectsUsingBlock:^(InspurUploadBlock *blockP, NSUInteger idx, BOOL * _Nonnull stop) {
        InspurUploadData *data = [blockP nextUploadDataWithoutCheckData];
        if (data != nil) {
            block = blockP;
            *stop = true;
        }
    }];
    return block;
}

// 加载块中的数据
// 1. 数据块已加载，直接返回
// 2. 数据块未加载，读块数据
// 2.1 如果未读到数据，则已 EOF，返回 null
// 2.2 如果读到数据
// 2.2.1 如果块数据符合预期，则当片未上传，则加载片数据
// 2.2.2 如果块数据不符合预期，创建新块，加载片信息
- (InspurUploadBlock *)loadBlockData:(InspurUploadBlock *)block error:(NSError **)error {
    if (block == nil) {
        return nil;
    }
    
    // 已经加载过 block 数据
    // 没有需要上传的片 或者 有需要上传片但是已加载过片数据
    InspurUploadData *nextUploadData = [block nextUploadDataWithoutCheckData];
    if (nextUploadData.state == InspurUploadStateWaitToUpload && nextUploadData.data != nil) {
        return block;
    }
    
    // 未加载过 block 数据
    // 根据 block 信息加载 blockBytes
    NSData *blockBytes = nil;
    blockBytes = [self readData:block.size dataOffset:block.offset error:error];
    if (*error != nil) {
        return nil;
    }

    // 没有数据不需要上传
    if (blockBytes == nil || blockBytes.length == 0) {
        return nil;
    }

    NSString *md5 = [blockBytes inspur_md5];
    // 判断当前 block 的数据是否和实际数据吻合，不吻合则之前 block 被抛弃，重新创建 block
    if (blockBytes.length != block.size || block.md5 == nil || ![block.md5 isEqualToString:md5]) {
        block = [[InspurUploadBlock alloc] initWithOffset:block.offset blockSize:blockBytes.length dataSize:self.dataSize index:block.index];
        block.md5 = md5;
    }

    for (InspurUploadData *data in block.uploadDataList) {
        if (data.state != InspurUploadStateComplete) {
            // 还未上传的
            data.data = [blockBytes subdataWithRange:NSMakeRange((NSUInteger)data.offset, (NSUInteger)data.size)];
            data.state = InspurUploadStateWaitToUpload;
        } else {
            // 已经上传的
            data.state = InspurUploadStateComplete;
        }
    }

    return block;
}

- (InspurUploadData *)nextUploadData:(InspurUploadBlock *)block {
    if (block == nil) {
        return nil;
    }
    return [block nextUploadDataWithoutCheckData];
}

- (NSArray <NSString *> *)allBlocksContexts {
    if (self.blockList == nil || self.blockList.count == 0) {
        return nil;
    }
    
    NSMutableArray *contexts = [NSMutableArray array];
    [self.blockList enumerateObjectsUsingBlock:^(InspurUploadBlock *block, NSUInteger idx, BOOL * _Nonnull stop) {
        if (block.context && block.context.length > 0) {
            [contexts addObject:block.context];
        }
    }];
    return [contexts copy];
}

@end
