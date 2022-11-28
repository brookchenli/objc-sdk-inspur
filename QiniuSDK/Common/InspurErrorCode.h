//
//  QNErrorCode.h
//  QiniuSDK
//
//  Created by Brook on 2020/10/21.
//  Copyright © 2020 Inspur. All rights reserved.
//

#import <Foundation/Foundation.h>
/**
 * StatusCode >= 100 见：https://developer.qiniu.com/kodo/3928/error-responses
 * 除上述链接及下面定义外的状态码依据 iOS 标准库定义
 */

/**
 *    中途取消的状态码
 */
extern const int kInspurRequestCancelled;

/**
 *    网络错误状态码
 */
extern const int kInspurNetworkError;

/**
 *    错误参数状态码
 */
extern const int kInspurInvalidArgument;

/**
 *    0 字节文件或数据
 */
extern const int kInspurZeroDataSize;

/**
 *    错误token状态码
 */
extern const int kInspurInvalidToken;

/**
 *    读取文件错误状态码
 */
extern const int kInspurFileError;

/**
 *    本地 I/O 错误
 */
extern const int kInspurLocalIOError;

/**
 *    ⽤户劫持错误 错误
 */
extern const int kInspurMaliciousResponseError;

/**
 *    没有可用的Host 错误【废弃】
 */
extern const int kInspurNoUsableHostError NS_UNAVAILABLE;

/**
 *    SDK 内部错误
 */
extern const int kInspurSDKInteriorError;

/**
 *    非预期的系统调用 错误
 */
extern const int kInspurUnexpectedSysCallError;
