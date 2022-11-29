//
//  InspurSignatureContentGenerator.m
//  InspurOSSSDK
//
//  Created by 陈历 on 2022/11/27.
//  Copyright © 2022 Inspur. All rights reserved.
//

#import "InspurSignatureContentGenerator.h"

@implementation InspurSignatureContentGenerator

- (NSString *)putData {
    //return [NSString stringWithFormat:@"PUT\n\n\n%@\n/%@%@", @"1682279793", @"chenli", @"/hello" ];
    return [NSString stringWithFormat:@"PUT\n\n\n%@\n/%@/%@", @(self.deadLine), self.bucket, [self safeKey] ];
}

- (NSString *)partInit {
    return [NSString stringWithFormat:@"POST\n\n\n%@\n/%@/%@?uploads", @(self.deadLine), self.bucket, [self safeKey] ];
}

- (NSString *)partUpload:(NSString *)uploadId partIndex:(NSString *)partIndex {
    NSString *needSignatureContent = [NSString stringWithFormat:@"PUT\n\n\n%@\n/%@/%@?partNumber=%@&uploadId=%@", @(self.deadLine), self.bucket, [self safeKey], partIndex, uploadId];
    return needSignatureContent;
}

- (NSArray <NSString *>*)partUpload:(NSString *)uploadId partIndex:(NSInteger)partIndex maxIndex:(int)maxIndex {
    NSMutableArray *tmpArray = [NSMutableArray array];
    for (int i = (int)partIndex; i <= maxIndex; i ++) {
        NSString *needSignatureContent = [NSString stringWithFormat:@"PUT\n\n\n%@\n/%@/%@?partNumber=%@&uploadId=%@", @(self.deadLine), self.bucket, self.key, @(i), uploadId];
        [tmpArray addObject:needSignatureContent];
    }
   
    return tmpArray;
}


- (NSString *)completeUpload:(NSString *)uploadId {
    NSString *needSignatureContent = [NSString stringWithFormat:@"POST\n\ntext/plain\n%@\n/%@/%@?uploadId=%@", @(self.deadLine), self.bucket, [self safeKey], uploadId];
    return needSignatureContent;
}

- (NSString *)safeKey {
    if (self.key.length > 0) {
        return self.key;
    }
    if (!_safeKey) {
        _safeKey = [NSString stringWithFormat:@"%@%@", [[NSUUID UUID] UUIDString], @((int)[[NSDate date] timeIntervalSince1970])];
    }
    return _safeKey;
}

- (void)updateKey:(NSString *)key {
    _key = key;
}

@end
