//
//  InspurUploadData.m
//  InspurOSSSDK
//
//  Created by Brook on 2021/5/10.
//  Copyright © 2021 Inspur. All rights reserved.
//

#import "InspurUploadData.h"

@interface InspurUploadData()

@property(nonatomic, assign)long long offset;
@property(nonatomic, assign)long long size;
@property(nonatomic, assign)NSInteger index;

@end
@implementation InspurUploadData

+ (instancetype)dataFromDictionary:(NSDictionary *)dictionary{
    if (![dictionary isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    InspurUploadData *data = [[InspurUploadData alloc] init];
    data.offset = [dictionary[@"offset"] longLongValue];
    data.size   = [dictionary[@"size"] longLongValue];
    data.index  = [dictionary[@"index"] integerValue];
    data.etag   = dictionary[@"etag"];
    data.md5    = dictionary[@"md5"];
    data.state  = [dictionary[@"state"] intValue];
    return data;
}

- (instancetype)initWithOffset:(long long)offset
                      dataSize:(long long)dataSize
                         index:(NSInteger)index {
    if (self = [super init]) {
        _offset = offset;
        _size = dataSize;
        _index = index;
        _etag = @"";
        _md5 = @"";
        _state = InspurUploadStateNeedToCheck;
    }
    return self;
}

- (BOOL)needToUpload {
    BOOL needToUpload = false;
    switch (self.state) {
        case InspurUploadStateNeedToCheck:
        case InspurUploadStateWaitToUpload:
            needToUpload = true;
            break;
        default:
            break;
    }
    return needToUpload;
}

- (BOOL)isUploaded {
    return self.state == InspurUploadStateComplete;
}

- (void)setState:(InspurUploadState)state {
    switch (state) {
        case InspurUploadStateNeedToCheck:
        case InspurUploadStateWaitToUpload:
        case InspurUploadStateUploading:
            self.uploadSize = 0;
            self.etag = @"";
            break;
        default:
            self.data = nil;
            break;
    }
    _state = state;
}

- (long long)uploadSize {
    if (self.state == InspurUploadStateComplete) {
        return _size;
    } else {
        return _uploadSize;
    }
}

- (void)clearUploadState{
    self.state = InspurUploadStateNeedToCheck;
    self.etag = nil;
    self.md5 = nil;
}

- (void)checkStateAndUpdate {
    if ((self.state == InspurUploadStateWaitToUpload || self.state == InspurUploadStateUploading) && self.data == nil) {
        self.state = InspurUploadStateNeedToCheck;
    }
}

- (NSDictionary *)toDictionary{
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    dictionary[@"offset"] = @(self.offset);
    dictionary[@"size"]   = @(self.size);
    dictionary[@"index"]  = @(self.index);
    dictionary[@"etag"]   = self.etag ?: @"";
    dictionary[@"md5"]    = self.md5 ?: @"";
    dictionary[@"state"]  = @(self.state);
    return [dictionary copy];
}

@end

