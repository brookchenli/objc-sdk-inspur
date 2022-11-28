//
//  QNSignatureContentGenerator.m
//  QiniuSDK
//
//  Created by 陈历 on 2022/11/27.
//  Copyright © 2022 Inspur. All rights reserved.
//

#import "InspurSignatureContentGenerator.h"

@implementation InspurSignatureContentGenerator

- (NSString *)putData {
    NSString *key =  self.key.length>0 ? [NSString stringWithFormat:@"/%@", self.key] : @"/";
    //return [NSString stringWithFormat:@"PUT\n\n\n%@\n/%@%@", @"1682279793", @"chenli", @"/hello" ];
    return [NSString stringWithFormat:@"PUT\n\n\n%@\n/%@%@", @(self.deadLine), self.bucket, key ];
}

- (NSString *)partInit {
    NSString *key =  self.key.length>0 ? [NSString stringWithFormat:@"/%@", self.key] : @"/";
    return [NSString stringWithFormat:@"POST\n\n\n%@\n/%@%@?uploads", @(self.deadLine), self.bucket, key ];
}

- (NSString *)partUpload:(NSString *)uploadId partIndex:(NSString *)partIndex {
    NSString *needSignatureContent = [NSString stringWithFormat:@"PUT\n\n\n%@\n/%@/%@?partNumber=%@&uploadId=%@", @(self.deadLine), self.bucket, self.key, partIndex, uploadId];
    return needSignatureContent;
}

- (NSString *)completeUpload:(NSString *)uploadId {
    NSString *needSignatureContent = [NSString stringWithFormat:@"POST\n\ntext/plain\n%@\n/%@/%@?uploadId=%@", @(self.deadLine), self.bucket, self.key, uploadId];
    return needSignatureContent;
}

@end
