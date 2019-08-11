//
//  GPUVideoFrame.h
//  Visionin
//
//  Created by Rex on 16/4/7.
//  Copyright © 2016年 Rex. All rights reserved.
//
#import "GL.h"
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>

#pragma mark - "VSVideoFrame"
@interface GPUVideoFrame : NSObject
@property(readonly, assign) UIView* preview;   // 预览view
@property(nonatomic, assign) CGSize videoSize;  // 视频流尺寸
@property(nonatomic, assign) CGSize outputSize; // 输出视频流尺寸，默认(0,0)，表示不裁剪不压缩
@property(nonatomic, assign) CGRect viewFrame;  // 预览窗口尺寸
@property(nonatomic, assign) gpu_fill_mode_t previewFillMode;   // 预览的视频显示填充模式，默认GPUFillModePreserveAspectRatioAndFill
@property(nonatomic, assign) CGSize previewSize;    // 预览的视频流尺寸，最终和previewFillMode配合填满预览窗口，最大作用是设置视频流的显示比例，如4：3，16：9等
@property(nonatomic, assign)AVCaptureDevicePosition     cameraPosition;         // 前后摄像头
@property(nonatomic, assign)UIInterfaceOrientation      outputImageOrientation; // 设备方向，默认UIInterfaceOrientationPortrait

// 输出预览和视频流旋转方向，如果设置会使视频流镜像函数失效，注意不能和镜像设置的4个参数同时使用
@property(nonatomic, assign) gpu_rotation_t previewRotation;
@property(nonatomic, assign) gpu_rotation_t outputRotation;
// 同时作用于预览和视频流，在blank之前修改
@property(nonatomic, assign) gpu_rotation_t frameRotation;

@property(nonatomic, assign) BOOL mirrorFrontFacingCamera;  // 前置摄像头视频流是否镜像显示
@property(nonatomic, assign) BOOL mirrorBackFacingCamera;   // 后置摄像头视频流是否镜像显示
@property(nonatomic, assign) BOOL mirrorFrontPreview;       // 前置摄像头下的preview镜像显示
@property(nonatomic, assign) BOOL mirrorBackPreview;        // 后置摄像头下的preview镜像显示

@property(nonatomic, assign) gpu_fill_mode_t outputFillMode;    // 输出视频流裁剪模式
// 以下两个方法如果没有设置AVCaptureConnection则不需要调用
@property(nonatomic, assign)AVCaptureVideoOrientation   frontVideoOrientation;  // 前置摄像头输出视频流方向, 默认为AVCaptureVideoOrientationLandscapeLeft
@property(nonatomic, assign)AVCaptureVideoOrientation   backVideoOrientation;   // 后置摄像头输出视频流方向, 默认为AVCaptureVideoOrientationLandscapeRight

// 当使用processVideoSampleBuffer时获取处理后数据使用以下回调
@property(nonatomic, copy)void (^bgraPixelBlock)(CVPixelBufferRef buffer, CMTime time);
@property(nonatomic, copy)void (^yuv420pPixelBlock)(unsigned char* buffer, CMTime time);    // I420
@property(nonatomic, copy)void (^nv21PixelBlock)(unsigned char* buffer, CMTime time);
@property(nonatomic, copy)void (^nv12PixelBlock)(unsigned char* buffer, CMTime time);
@property(nonatomic, copy)void (^textureBlock)(unsigned int texture, CMTime time);   // 返回处理后的texture
@property(nonatomic, copy)void (^rawPixelBlock)(CVPixelBufferRef buffer, CMTime time); // 返回未处理的调正的原始视频流
// 当使用processVideoBytes时获取处理后数据使用以下回调
@property(nonatomic, copy)void (^bgraBytesBlock)(unsigned char* buffer,int width,int height);
@property(nonatomic, copy)void (^nv21BytesBlock)(unsigned char* buffer,int width,int height);
@property(nonatomic, copy)void (^nv12BytesBlock)(unsigned char* buffer,int width,int height);

// 当前帧的时间戳
@property(readonly, assign)CMTime presentTimeStamp;
// 磨皮，范围:0-1.0
@property(nonatomic, assign) float smoothStrength;
// 美白
@property(nonatomic, assign) float whitenStrength;

/*
 * position:
 * pixelFormat: 摄像头输出视频帧格式，目前支持格式类型：kCVPixelFormatType_420YpCbCr8BiPlanarFullRange、kCVPixelFormatType_32BGRA、kCVPixelFormatType_32RGBA
 * view：视频预览窗口
 */
-(id)initWithPosition:(AVCaptureDevicePosition)position view:(UIView*)view;
/*
 * position:
 * format: 输入Bytes格式，目前支持格式类型：“1”为RGBA 、“2”为NV21、"6"为NV12
 * view：视频预览窗口
 */
-(id)initWithPositionByBytes:(AVCaptureDevicePosition)position format:(int)format view:(UIView*)view;
// 涉及状态机维护，启动摄像头时候调用start，关闭摄像头时调用stop
-(void)startVideoFrame;
-(void)stopVideoFrame;
// 输入要处理的视频流, 返回错误表示上一帧还没有处理完，本次samplebuffer被丢弃
-(BOOL)processVideoSampleBuffer:(CMSampleBufferRef)sampleBuffer;
-(BOOL)processVideoPixelBuffer:(CVPixelBufferRef)pixelBuffer;
-(BOOL)processCGImage:(CGImageRef)cgImage;
// 处理输入的bytes流
-(BOOL)processVideoBytes:(unsigned char*)bytes width:(int)width height:(int)height format:(int)format;

// 设置滤镜
-(void)setExtraFilter:(NSString*)filterName;
-(void)closeExtraFilter;
// 设置滤镜参数
-(void)setExtraParameter:(float)para;
// 设置背景图
-(void)setBackground:(UIImage*)image;
-(void)removeBackground;

// 为preview叠加图片，例如添加logo, rect是归一化坐标，范围0-1.
// 注意mirror仅仅表示图片镜像，实际显示的位置会受到mirrorFrontPreview和mirrorBackPreview的影响
-(void)setPreviewBlend:(UIImage*)image rect:(CGRect)rect mirror:(BOOL)mirror;
// 为preview叠加图片，指定宽和高， RGBA格式
// 注意mirror仅仅表示图片镜像，实际显示的位置会受到mirrorFrontPreview和mirrorBackPreview的影响
-(void)setPreviewBlend:(unsigned char*)bytes width:(int)w height:(int)h rect:(CGRect)rect  mirror:(BOOL)mirror;
-(void)removePreviewBlend;
// 为视频流叠加图片, rect是归一化坐标，范围0-1
-(void)setVideoBlend:(UIImage*)image rect:(CGRect)rect mirror:(BOOL)mirror;
// 为视频流叠加图片，指定宽和高，RGBA格式
-(void)setVideoBlend:(unsigned char*)bytes width:(int)w height:(int)h rect:(CGRect)rect mirror:(BOOL)mirror;
-(void)removeVideoBlend;

// 滤镜：曝光、锐化、对比度等滤镜
-(void)setColorFilter:(int)filter strength:(float)strength;
-(void)setUnBlurRegion:(CGPoint)center radius:(int)radius;
// 设置视频流尺寸，可以作用于预览及输出视频流
-(void)setFrameSize:(CGSize)size;
// 添加边框
-(void)setBlank:(int)blank color:(UIColor*)color;
// 预览背景颜色
-(void)setPreviewColor:(UIColor*)color;
// 显示的销毁
-(void)destroy;
@end

// 实时滤镜
#define GPU_GAUSSIAN_BLUR_FILTER     @"GaussianBlur"      // 高斯模糊
#define GPU_MEDIAN_BLUR_FILTER       @"MedianBlur"        // 中值滤波
#define GPU_FROSTED_BLUR_FILTER      @"FrostedBlur"       // iOS7毛玻璃
#define GPU_SATURATION_FILTER        @"Saturation"        // 饱和度

#define GPU_COLOR_CONTRAST_FILTER   0       // 对比度
#define GPU_COLOR_GAMMA_FILTER      1       // 曝光度
#define GPU_COLOR_SATURATION_FILTER 2       // 饱和度
#define GPU_COLOR_FADE_FILTER       3       // 褪色
#define GPU_COLOR_BLUR_FILTER       4       // 模糊
#define GPU_COLOR_SHARPNESS_FILTER  5       // 锐化
#define GPU_COLOR_TEMPERATURE_FILTER 6      // 色温
#define GPU_COLOR_TINT_FILTER       7       // 色调
#define GPU_COLOR_HIGHLIGHTS_FILTER 8       // 高光
#define GPU_COLOR_SHADOWS_FILTER    9       // 阴影
#define GPU_COLOR_VIGNETTE_FILTER   10      // 暗角
