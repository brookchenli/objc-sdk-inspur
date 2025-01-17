//
//  InspurUploadInfo.m
//  InspurOSSSDK
//
//  Created by Brook on 2021/5/10.
//  Copyright © 2021 Inspur. All rights reserved.
//

#import "InspurErrorCode.h"
#import "InspurUploadInfo.h"

@interface InspurUploadInfo()

@property(nonatomic,  copy)NSString *sourceId;
@property(nonatomic, assign)long long sourceSize;
@property(nonatomic,  copy)NSString *fileName;

@property(nonatomic, strong)id <InspurUploadSource> source;

@end
@implementation InspurUploadInfo

+ (instancetype)info:(id <InspurUploadSource>)source {
    InspurUploadInfo *info = [[self alloc] init];
    info.source = source;
    info.sourceSize = [source getSize];
    info.fileName = [source getFileName];
    return info;
}

- (void)setInfoFromDictionary:(NSDictionary *)dictionary {
    self.sourceSize = [dictionary[@"sourceSize"] longValue];
    self.sourceId = dictionary[@"sourceId"];
}

- (NSDictionary *)toDictionary {
    return @{@"sourceSize" : @([self getSourceSize]),
             @"sourceId" : self.sourceId ?: @""};
}

- (BOOL)hasValidResource {
    return self.source != nil;
}

- (BOOL)isValid {
    return [self hasValidResource];
}

- (BOOL)couldReloadSource {
    return [self.source couldReloadSource];
}

- (BOOL)reloadSource {
    return [self.source reloadSource];
}

- (NSString *)getSourceId {
    return [self.source getId];
}

- (long long)getSourceSize {
    return [self.source getSize];
}

- (BOOL)isSameUploadInfo:(InspurUploadInfo *)info {
    if (info == nil || ((self.sourceId.length > 0 || info.sourceId.length > 0) && ![self.sourceId isEqualToString:info.sourceId])) {
        return false;
    }
    
    // 检测文件大小，如果能获取到文件大小的话，就进行检测
    if (info.sourceSize > kInspurUnknownSourceSize &&
        self.sourceSize > kInspurUnknownSourceSize &&
        info.sourceSize != self.sourceSize) {
        return false;
    }

    return true;
}

- (long long)uploadSize {
    return 0;
}

- (BOOL)isAllUploaded {
    return true;
}

- (void)clearUploadState {
}

- (void)checkInfoStateAndUpdate {
}

- (NSData *)readData:(NSInteger)dataSize dataOffset:(long long)dataOffset error:(NSError **)error {
    if (!self.source) {
        *error = [NSError errorWithDomain:NSStreamSOCKSErrorDomain code:kInspurLocalIOError userInfo:@{NSLocalizedDescriptionKey : @"file is not exist"}];
        return nil;
    }
    
    NSData *data = nil;
    @synchronized (self.source) {
        data = [self.source readData:dataSize dataOffset:dataOffset error:error];
    }
    if (*error == nil && data != nil && (data.length == 0 || data.length != dataSize)) {
        self.sourceSize = data.length + dataOffset;
    }
    return data;
}

- (void)close {
    [self.source close];
}

@end

