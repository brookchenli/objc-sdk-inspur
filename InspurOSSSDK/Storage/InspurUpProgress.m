//
//  InspurUpProgress.m
//  InspurOSSSDK
//
//  Created by Brook on 2021/5/21.
//  Copyright © 2021 Inspur. All rights reserved.
//

#import "InspurAsyncRun.h"
#import "InspurUpProgress.h"

@interface InspurUpProgress()

@property(nonatomic, assign)long long maxProgressUploadBytes;
@property(nonatomic, assign)long long previousUploadBytes;
@property(nonatomic,  copy)InspurUpProgressHandler progress;
@property(nonatomic,  copy)InspurUpByteProgressHandler byteProgress;

@end
@implementation InspurUpProgress

+ (instancetype)progress:(InspurUpProgressHandler)progress byteProgress:(InspurUpByteProgressHandler)byteProgress {
    InspurUpProgress *upProgress = [[InspurUpProgress alloc] init];
    upProgress.maxProgressUploadBytes = -1;
    upProgress.previousUploadBytes = 0;
    upProgress.progress = progress;
    upProgress.byteProgress = byteProgress;
    return upProgress;
}

- (void)progress:(NSString *)key uploadBytes:(long long)uploadBytes totalBytes:(long long)totalBytes {
    if ((self.progress == nil && self.byteProgress == nil) || uploadBytes < 0 || (totalBytes > 0 && uploadBytes > totalBytes)) {
        return;
    }
    
    if (totalBytes > 0) {
        if (self.maxProgressUploadBytes < 0) {
            self.maxProgressUploadBytes = totalBytes * 0.95;
        }
        
        if (uploadBytes > self.maxProgressUploadBytes) {
            return;
        }
    }
    
    if (uploadBytes > self.previousUploadBytes) {
        self.previousUploadBytes = uploadBytes;
    } else {
        return;
    }
    
    if (self.byteProgress) {
        InspurAsyncRunInMain(^{
            self.byteProgress(key, self.previousUploadBytes, totalBytes);
        });
        return;
    }
    
    if (totalBytes < 0) {
        return;
    }
    
    if (self.progress) {
        InspurAsyncRunInMain(^{
            double notifyPercent = (double) uploadBytes / (double) totalBytes;
            self.progress(key, notifyPercent);
        });
    }
}

- (void)notifyDone:(NSString *)key totalBytes:(long long)totalBytes {
    if (self.progress == nil && self.byteProgress == nil) {
        return;
    }
    
    if (self.byteProgress) {
        InspurAsyncRunInMain(^{
            self.byteProgress(key, totalBytes, totalBytes);
        });
        return;
    }
    
    if (self.progress) {
        InspurAsyncRunInMain(^{
            self.progress(key, 1);
        });
    }
}

@end
