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
@property(nonatomic, assign)AVCaptureDevicePosition     cameraPosition;         // 前后摄像头
@property(nonatomic, assign)UIInterfaceOrientation      outputImageOrientation; // 设备方向，默认UIInterfaceOrientationPortrait

// 输出视频流旋转方向，如果设置会使视频流镜像函数失效，注意不能和镜像设置的4个参数同时使用
@property(nonatomic, assign) gpu_rotation_t outputRotation;

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
// 当使用processVideoBytes时获取处理后数据使用以下回调
@property(nonatomic, copy)void (^bgraBytesBlock)(unsigned char* buffer,int width,int height);
@property(nonatomic, copy)void (^nv21BytesBlock)(unsigned char* buffer,int width,int height);
@property(nonatomic, copy)void (^nv12BytesBlock)(unsigned char* buffer,int width,int height);

// 当前帧的时间戳
@property(readonly, assign)CMTime presentTimeStamp;
// 磨皮，范围:0-1.0
@property(nonatomic, assign) float smoothStrength;

/*
 * position:
 * pixelFormat: 摄像头输出视频帧格式，目前支持格式类型：kCVPixelFormatType_420YpCbCr8BiPlanarFullRange、kCVPixelFormatType_32BGRA、kCVPixelFormatType_32RGBA
 * view：视频预览窗口
 */
-(id)initWithPosition:(AVCaptureDevicePosition)position pixelFormat:(OSType)format view:(UIView*)view;
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
@end

// 实时滤镜
#define VS_GAUSSIAN_BLUR_FILTER     @"GaussianBlur"      // 高斯模糊
#define VS_MEDIAN_BLUR_FILTER       @"MedianBlur"        // 中值滤波
#define VS_FROSTED_BLUR_FILTER      @"FrostedBlur"       // iOS7毛玻璃
#define VS_SATURATION_FILTER        @"Saturation"        // 饱和度
