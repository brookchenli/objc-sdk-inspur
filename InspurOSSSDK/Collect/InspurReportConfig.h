//
//  InspurReportConfig.h
//  InspurOSSSDK
//
//  Created by Brook on 2020/7/14.
//  Copyright © 2020 Inspur. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface InspurReportConfig : NSObject

- (id)init __attribute__((unavailable("Use sharedInstance: instead.")));
+ (instancetype)sharedInstance;

/**
 *  是否开启sdk上传信息搜集  默认为YES
 */
@property (nonatomic, assign, getter=isReportEnable) BOOL reportEnable;

/**
 *  每次上传时间间隔  单位：分钟  默认为0.5分钟
 */
@property (nonatomic, assign) double interval;

/**
 *  记录文件大于 uploadThreshold 会触发上传，单位：字节  默认为16 * 1024
 */
@property (nonatomic, assign) uint64_t uploadThreshold;

/**
 *  记录文件最大值  要大于 uploadThreshold  单位：字节  默认为20 * 1024 * 1024
 */
@property (nonatomic, assign) uint64_t maxRecordFileSize;

/**
 *  记录文件所在文件夹目录  默认为：.../沙盒/Library/Caches/com.qiniu.report
 */
@property (nonatomic, copy) NSString *recordDirectory;

/**
 *  信息上报服务器地址
 */
@property (nonatomic, copy, readonly) NSString *serverURL;

/**
 *  信息上报服务器地址 host
 */
@property (nonatomic, copy, readonly) NSString *serverHost;

/**
 *  信息上报请求超时时间  单位：秒  默认为10秒
 */
@property (nonatomic, assign, readonly) NSTimeInterval timeoutInterval;

@end

NS_ASSUME_NONNULL_END
