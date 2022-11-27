//
//  QNSignatureContentGenerator.m
//  QiniuSDK
//
//  Created by 陈历 on 2022/11/27.
//  Copyright © 2022 Qiniu. All rights reserved.
//

#import "QNSignatureContentGenerator.h"

@implementation QNSignatureContentGenerator

- (NSString *)putData {
    NSString *key =  self.key.length>0 ? [NSString stringWithFormat:@"/%@", self.key] : @"/";
    //return [NSString stringWithFormat:@"PUT\n\n\n%@\n/%@%@", @"1682279793", @"chenli", @"/hello" ];
    return [NSString stringWithFormat:@"PUT\n\n\n%@\n/%@%@", @(self.deadLine), self.bucket, key ];
}

@end