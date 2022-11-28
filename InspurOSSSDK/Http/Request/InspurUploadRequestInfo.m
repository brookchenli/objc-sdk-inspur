//
//  InspurUploadRequestInfo.m
//  InspurOSSSDK_Mac
//
//  Created by Brook on 2020/5/13.
//  Copyright © 2020 Inspur. All rights reserved.
//

#import "InspurUploadRequestInfo.h"

@implementation InspurUploadRequestInfo

- (BOOL)shouldReportRequestLog{
    return ![self.requestType isEqualToString:QNUploadRequestTypeUpLog];
}

@end

NSString * const QNUploadRequestTypeUCQuery = @"uc_query";
NSString * const QNUploadRequestTypeForm = @"form";
NSString * const QNUploadRequestTypeMkblk = @"mkblk";
NSString * const QNUploadRequestTypeBput = @"bput";
NSString * const QNUploadRequestTypeMkfile = @"mkfile";
NSString * const QNUploadRequestTypeInitParts = @"init_parts";
NSString * const QNUploadRequestTypeUploadPart = @"upload_part";
NSString * const QNUploadRequestTypeCompletePart = @"complete_part";
NSString * const QNUploadRequestTypeServerConfig = @"server_config";
NSString * const QNUploadRequestTypeServerUserConfig = @"server_user_config";
NSString * const QNUploadRequestTypeUpLog = @"uplog";
