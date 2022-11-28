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
    return ![self.requestType isEqualToString:InspurUploadRequestTypeUpLog];
}

@end

NSString * const InspurUploadRequestTypeUCQuery = @"uc_query";
NSString * const InspurUploadRequestTypeForm = @"form";
NSString * const InspurUploadRequestTypeMkblk = @"mkblk";
NSString * const InspurUploadRequestTypeBput = @"bput";
NSString * const InspurUploadRequestTypeMkfile = @"mkfile";
NSString * const InspurUploadRequestTypeInitParts = @"init_parts";
NSString * const InspurUploadRequestTypeUploadPart = @"upload_part";
NSString * const InspurUploadRequestTypeCompletePart = @"complete_part";
NSString * const InspurUploadRequestTypeServerConfig = @"server_config";
NSString * const InspurUploadRequestTypeServerUserConfig = @"server_user_config";
NSString * const InspurUploadRequestTypeUpLog = @"uplog";
