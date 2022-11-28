//
//  InspurImageProcess.h
//  InspurOSSDemo
//
//  Created by 陈历 on 2022/11/28.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class InspurImageAttribute;
@class InspurImageAttributeMaker;

typedef void (^InspurImageAttributeMakerBlock)(InspurImageAttributeMaker *maker);

typedef NS_ENUM(NSUInteger, InspurImageFlip) {
    InspurImageFlipNone,
    InspurImageFlipHorizontal,
    InspurImageFlipVertical
};

typedef NS_ENUM(NSUInteger, InspurImageResizeMode) {
    InspurImageResizeModeNone,
    InspurImageResizeModeLfit,
    InspurImageResizeModeMfit,
    InspurImageResizeModeFill,
    InspurImageResizeModePad,
    InspurImageResizeModeFixed
};

typedef NS_ENUM(NSUInteger, InspurImageWaterMarkPosition) {
    InspurImageWaterMarkPositionNone,
    InspurImageWaterMarkPositionTL,
    InspurImageWaterMarkPositionTop,
    InspurImageWaterMarkPositionTR,
    InspurImageWaterMarkPositionLeft,
    InspurImageWaterMarkPositionCenter,
    InspurImageWaterMarkPositionRight,
    InspurImageWaterMarkPositionBL,
    InspurImageWaterMarkPositionBottom,
    InspurImageWaterMarkPositionBR
};

@interface InspurImageAttributeMaker : NSObject

- (InspurImageAttributeMaker *(^)(NSString *styleName))style;
- (InspurImageAttributeMaker *(^)(int))rotato;
- (InspurImageAttributeMaker *(^)(InspurImageFlip flip))flip;
- (InspurImageAttributeMaker *(^)(int resize))fitResize;
- (InspurImageAttributeMaker *(^)(InspurImageResizeMode mode,
                                  NSNumber* _Nullable w,
                                  NSNumber* _Nullable h,
                                  NSNumber* _Nullable s,
                                  NSNumber* _Nullable l ,
                                  NSNumber* _Nullable limit,
                                  NSString * _Nullable color))resize;
//TODO: 格式转换
- (InspurImageAttributeMaker *(^)(int bright))bright;
- (InspurImageAttributeMaker *(^)(float contrast))contrast;
- (InspurImageAttributeMaker *(^)(float sharpen))sharpen;

/*
 三种字体:
 @"思源宋体"
 @"思源黑体"
 @"文泉微米黑"
 **/
- (InspurImageAttributeMaker *(^)(NSString *text, NSString *font, NSString *color, NSNumber *size, InspurImageWaterMarkPosition position, NSNumber *x, NSNumber *y, NSNumber *t, NSString *url))watermark;
- (InspurImageAttributeMaker *(^)(int interlace))interlace;
- (InspurImageAttributeMaker *(^)(BOOL isX, int value, int index))indexcrop;
- (InspurImageAttributeMaker *(^)(int radius))circle;
- (InspurImageAttributeMaker *(^)(int radius))roundedCorners;
- (InspurImageAttributeMaker *(^)(NSString *))format;
- (InspurImageAttributeMaker *(^)(int quality))quality;

- (InspurImageAttributeMaker *(^)(void))averageHue;
- (InspurImageAttributeMaker *(^)(void))info;

@end

@interface InspurImageProcess : NSObject

@property (nonatomic, strong) NSString *originalUrl;
@property (nonatomic, strong) NSString *url;

- (instancetype)initWithURL:(NSString *)url;

- (instancetype)make:(InspurImageAttributeMakerBlock)block;


@end

NS_ASSUME_NONNULL_END
