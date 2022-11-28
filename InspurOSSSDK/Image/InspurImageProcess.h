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

#define InspurImageWaterMarkPositionTL @"tl"
#define InspurImageWaterMarkPositionTop @"top"
#define InspurImageWaterMarkPositionTR @"tr"
#define InspurImageWaterMarkPositionLeft @"left"
#define InspurImageWaterMarkPositionCenter @"center"
#define InspurImageWaterMarkPositionRight @"right"
#define InspurImageWaterMarkPositionBL @"bl"
#define InspurImageWaterMarkPositionBottom @"bottom"
#define InspurImageWaterMarkPositionBR @"br"

#define InspurImageWaterMarkFontSiyuanSongti @"思源宋体"
#define InspurImageWaterMarkFontSiyuanHeiti @"思源黑体"
#define InspurImageWaterMarkFontWequan @"文泉微米黑"

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

@interface InspurImageWaterMarkParams : NSObject

//文字水印
- (instancetype)initWithText:(NSString *)text
                       color:(NSString *)color
                        font:(NSString *)font
                        size:(int)fontSize
                 transparent:(int)t
                    position:(NSString *)position
                     xMargin:(int)x
                     yMargin:(int)y;

//图片水印
- (instancetype)initWithImage:(NSString *)imageUrl
                 transparent:(int)t
                    position:(NSString *)position
                     xMargin:(CGFloat)x
                     yMargin:(CGFloat)y;

- (NSString *)toString;

@end

@interface InspurImageAttributeMaker : NSObject
/*
 选择模版
 */
- (InspurImageAttributeMaker *(^)(NSString *styleName))style;
/*
 图片旋转, 取值范围 0-359
 */
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
- (InspurImageAttributeMaker *(^)(int bright))bright;
- (InspurImageAttributeMaker *(^)(float contrast))contrast;
- (InspurImageAttributeMaker *(^)(float sharpen))sharpen;

- (InspurImageAttributeMaker *(^)(NSArray <InspurImageWaterMarkParams *> *waterMarks))watermark;
- (InspurImageAttributeMaker *(^)(InspurImageWaterMarkParams *waterMark))blindWatermark;
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
