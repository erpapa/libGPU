//
//  GPUVideoFrame.m
//  Visionin
//
//  Created by Rex on 16/4/7.
//  Copyright © 2016年 Rex. All rights reserved.
//

#include "GPU.h"
#import "GPUVideoFrame.h"
#include "GPUIOSView.h"
#include "GPUIOSBuffer.h"
#include "GPUContext.h"
#include "GPUStreamFrame.h"
#include "GPUPicture.h"
#include "GPUSampleBufferInput.h"

// 如果作为VSVideoFrame成员变量，在VSVideoFrame销毁时需要释放，可能此时正在访问http，会引起崩溃

@interface GPUVideoFrame(){
    GPUSampleBufferInput*   bufferInput;
    GPUIOSView*             playView;
    GPUPicture*             background;
    GPURawInput*            rawInput;
    GPUFilter               rawFilter;
    GPUStreamFrame*         streamFrame;
    
    BOOL                    running;
    BOOL                    closeBeauty;
    CGSize                  originSize;
    BOOL                    isProcessing;
    
    int                     rotateAngle;
}

@end

@implementation GPUVideoFrame

#pragma -mark "初始化"
-(id)initWithPosition:(AVCaptureDevicePosition)position view:(UIView*)view{
    self = [super init];
    if (self==nil) {
        return nil;
    }
    
    bs_log_init("stdout");
    GPUContext::shareInstance()->makeCurrent();
    GPUIOSBufferCache::shareInstance();
    
    running = FALSE;
    isProcessing = FALSE;
    _smoothStrength = 0.0;
    _cameraPosition = position;
    _outputSize = CGSizeMake(0, 0);
    _videoSize = CGSizeMake(0, 0);
    originSize = CGSizeMake(0, 0);
    
//    if (format == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange) {
//        bufferInput = new VSSampleBufferInput(position, GPU_NV12);
//        streamFrame = new VSStreamFrame(GPU_NV12);
//    }
//    else if(format == kCVPixelFormatType_32BGRA){
//        bufferInput = new VSSampleBufferInput(position, GPU_BGRA);
//        streamFrame = new VSStreamFrame(GPU_RGBA);
//    }
//    else if(format == kCVPixelFormatType_32RGBA){
//        bufferInput = new VSSampleBufferInput(position, GPU_RGBA);
//        streamFrame = new VSStreamFrame(GPU_RGBA);
//    }
    bufferInput = new GPUSampleBufferInput();
    
    _outputImageOrientation = UIInterfaceOrientationPortrait;
    _frontVideoOrientation = AVCaptureVideoOrientationLandscapeLeft;
    _backVideoOrientation = AVCaptureVideoOrientationLandscapeRight;
    
    streamFrame = GPUStreamFrame::shareInstance();
    streamFrame->setInputFormat(GPU_RGBA);
    bufferInput->addTarget(streamFrame);
    
    if(view != nil){
        [self setPlayView:view];
    }
    
    _mirrorFrontFacingCamera = TRUE;
    _mirrorBackFacingCamera = NO;
    _mirrorFrontPreview = YES;
    _mirrorBackPreview = NO;
    self.cameraPosition = position;
    
    closeBeauty = FALSE;
    
    return self;
}

#pragma -mark "初始化"
-(id)initWithPositionByBytes:(AVCaptureDevicePosition)position format:(int)format view:(UIView*)view {
    self = [super init];
    if (self==nil) {
        return nil;
    }
    
    bs_log_init("stdout");    
    GPUContext::shareInstance()->makeCurrent();
    GPUIOSBufferCache::shareInstance();
    
    running = FALSE;
    isProcessing = FALSE;
    _smoothStrength = 0.0;
    _cameraPosition = position;
    _outputSize = CGSizeMake(0, 0);
    _videoSize = CGSizeMake(0, 0);
    originSize = CGSizeMake(0, 0);
    
    streamFrame = new GPUStreamFrame();
    streamFrame->setInputFormat(GPU_RGBA);
    
    _outputImageOrientation = UIInterfaceOrientationPortrait;
    _frontVideoOrientation = AVCaptureVideoOrientationLandscapeLeft;
    _backVideoOrientation = AVCaptureVideoOrientationLandscapeRight;
    
    if(view != nil){
        [self setPlayView:view];
    }
    
    _mirrorFrontFacingCamera = TRUE;
    _mirrorBackFacingCamera = NO;
    _mirrorFrontPreview = YES;
    _mirrorBackPreview = NO;
    self.cameraPosition = position;
    
    closeBeauty = FALSE;
    
    return self;
}

#pragma -mark "开始关闭控制"
-(void)startVideoFrame{
    if (running) {
        NSLog(@"Error: VSVideoFrame is Running!");
        return;
    }
    running = TRUE;
    NSLog(@"Start Visionin Success!");
}

-(void)stopVideoFrame{
    if (!running) {
        NSLog(@"Error: VSVideoFrame isn't Running!");
        return;
    }
    running = FALSE;
    while (isProcessing)
    {
        [NSThread sleepForTimeInterval:0.01f];
    }
    
    NSLog(@"Stop Visionin Success!");
}

-(BOOL)processVideoBytes:(unsigned char*)bytes width:(int)width height:(int)height format:(int)format{
    if (!running) {
        NSLog(@"Error: VSVideoFrame isn't Running! Skip Video bytes");
        return FALSE;
    }
    
    if (isProcessing) {
        return FALSE;
    }
    isProcessing = TRUE;
    if(!bytes){
        NSLog(@"bytes is NULL!");
        return FALSE;
    }
    isProcessing = TRUE;
    
    if ((height!=originSize.height || width!=originSize.width)){
        originSize = CGSizeMake(width, height);
        [self setVideoSize];
    }
    
    if(!rawInput){
        rawInput = new GPURawInput((gpu_pixel_format_t)format);
        
        rawInput ->addTarget(streamFrame);
    }
    streamFrame->setInputFormat((gpu_pixel_format_t)format);
    rawInput->uploadBytes(bytes, width, height,(gpu_pixel_format_t)format);
    if(_bgraBytesBlock!=nil){
        _bgraBytesBlock(streamFrame->m_raw_output->getBuffer(),width,height);
    }
    if(_nv21BytesBlock!=nil){
        _nv21BytesBlock(streamFrame->m_raw_output->getBuffer(),width,height);
    }
    if(_nv12BytesBlock!=nil){
        _nv12BytesBlock(streamFrame->m_raw_output->getBuffer(),width,height);
    }
    
//    g_service_log->refresh();
    isProcessing = FALSE;
    return TRUE;
    
}

-(BOOL)processVideoSampleBuffer:(CMSampleBufferRef)sampleBuffer{
    if (!running) {
        NSLog(@"Error: VSVideoFrame isn't Running! Skip Video SampleBuffer");
        return FALSE;
    }
    
    if (isProcessing) {
        return FALSE;
    }
    isProcessing = TRUE;
    
    // 获取时间戳
    _presentTimeStamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
    CVPixelBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    return [self processVideoPixelBuffer:imageBuffer];
}
-(BOOL)processVideoPixelBuffer:(CVPixelBufferRef)imageBuffer{
    //CVPixelBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    float width = CVPixelBufferGetWidth(imageBuffer);
    float height = CVPixelBufferGetHeight(imageBuffer);
    
    if ((height!=originSize.height || width!=originSize.width)){
        originSize = CGSizeMake(width, height);
        [self setVideoSize];
    }
    
    bufferInput->processPixelBuffer(imageBuffer);
    glFinish();
    
    if (_rawPixelBlock!=nil){
        GPUIOSFrameBuffer* outbuffer = (GPUIOSFrameBuffer*)rawFilter.m_outbuffer;
        if(outbuffer != NULL){
            CVPixelBufferRef pixel = outbuffer->getPixelBuffer();
            _rawPixelBlock(pixel, _presentTimeStamp);
        }
    }
    
    if (_bgraPixelBlock!=nil) {
        GPUIOSFrameBuffer* outbuffer = (GPUIOSFrameBuffer*)streamFrame->m_zoom_filter.m_outbuffer;
        if(outbuffer == NULL){
            err_log("Visionin Error: ZoomFilter not run!");
            isProcessing = FALSE;
            return FALSE;
        }
        else {
            CVPixelBufferRef pixel = outbuffer->getPixelBuffer();
            _bgraPixelBlock(pixel, _presentTimeStamp);
        }
    }
    
    if (_yuv420pPixelBlock!=nil) {
        _yuv420pPixelBlock(streamFrame->m_raw_output->getBuffer(), _presentTimeStamp);
    }
    if (_nv21PixelBlock!=nil) {
        _nv21PixelBlock(streamFrame->m_raw_output->getBuffer(), _presentTimeStamp);
    }
    if (_nv12PixelBlock!=nil) {
        _nv12PixelBlock(streamFrame->m_raw_output->getBuffer(), _presentTimeStamp);
    }
    if (_textureBlock!=nil) {
        if ((GPUIOSFrameBuffer*)streamFrame->m_zoom_filter.m_outbuffer==NULL) {
            err_log("Visionin Error: ZoomFilter not run!");
            isProcessing = FALSE;
            return FALSE;
        }
        
        GPUIOSFrameBuffer* outbuffer = (GPUIOSFrameBuffer*)streamFrame->m_zoom_filter.m_outbuffer;
        if (outbuffer!=NULL) {
            _textureBlock(outbuffer->m_texture, _presentTimeStamp);
        }
    }
    
//    g_service_log->refresh();
    isProcessing = FALSE;
    return TRUE;
}
-(BOOL)processCGImage:(CGImageRef)cgImage{
    GPUPicture picture((void*)cgImage);
    picture.addTarget(streamFrame);
    picture.processImage();
    // 释放
    picture.removeAllTargets();
    
    if (_bgraPixelBlock!=nil) {
        GPUIOSFrameBuffer* outbuffer = (GPUIOSFrameBuffer*)streamFrame->m_zoom_filter.m_outbuffer;
        if(outbuffer == NULL){
            err_log("Visionin Error: ZoomFilter not run!");
            isProcessing = FALSE;
            return FALSE;
        }
        else {
            glFinish();
            CVPixelBufferRef pixel = outbuffer->getPixelBuffer();
            _bgraPixelBlock(pixel, _presentTimeStamp);
        }
    }
    if (_yuv420pPixelBlock!=nil) {
        _yuv420pPixelBlock(streamFrame->m_raw_output->getBuffer(), _presentTimeStamp);
    }
    if (_nv21PixelBlock!=nil) {
        _nv21PixelBlock(streamFrame->m_raw_output->getBuffer(), _presentTimeStamp);
    }
    if (_nv12PixelBlock!=nil) {
        _nv12PixelBlock(streamFrame->m_raw_output->getBuffer(), _presentTimeStamp);
    }
    if (_textureBlock!=nil) {
        if ((GPUIOSFrameBuffer*)streamFrame->m_zoom_filter.m_outbuffer==NULL) {
            err_log("Visionin Error: ZoomFilter not run!");
            isProcessing = FALSE;
            return FALSE;
        }
        
        GPUIOSFrameBuffer* outbuffer = (GPUIOSFrameBuffer*)streamFrame->m_zoom_filter.m_outbuffer;
        if (outbuffer!=NULL) {
            _textureBlock(outbuffer->m_texture, _presentTimeStamp);
        }
    }
    
    return TRUE;
}
//-(void)setPreview:(UIView *)preview{
//    if (preview==nil) {
//        return;
//    }
//    
//    _preview  = preview;
//    if (playView!=nil) {
//        streamFrame->removeOutputView();
//        [playView->uiview() removeFromSuperview];
//        playView->removeAllSources();
//        delete playView;
//        playView = nil;
//    }
//    playView = new GPUIOSView(_preview.bounds);
//    [playView->uiview() setFillMode:GPUFillModePreserveAspectRatioAndFill];
//    streamFrame->setOutputView(playView);
//    
//    if ([NSThread isMainThread]) {
//        [_preview addSubview:playView->uiview()];
//    }
//    else{
//        dispatch_async(dispatch_get_main_queue(), ^(){
//            [_preview addSubview:playView->uiview()];
//        });
//    }
//}

-(void)setPlayView:(UIView*)view{
    playView = new GPUIOSView(view.bounds);
    [playView->uiview() setFillMode:GPUFillModePreserveAspectRatioAndFill];
    streamFrame->setOutputView(playView);
    _preview = playView->uiview();
    
    if ([NSThread isMainThread]) {
        [view addSubview:playView->uiview()];
    }
    else{
        dispatch_async(dispatch_get_main_queue(), ^(){
            [view addSubview:playView->uiview()];
        });
    }
}

-(void)setViewFrame:(CGRect)viewFrame{
    if ([NSThread isMainThread]) {
        [playView->uiview() setFrame:viewFrame];
    }
    else{
        dispatch_async(dispatch_get_main_queue(), ^(){
            [playView->uiview() setFrame:viewFrame];
        });
    }
}

#pragma -mark "显示方向控制"
-(void)setCameraPosition:(AVCaptureDevicePosition)cameraPosition{
    _cameraPosition = cameraPosition;
    // 根据设备方向和视频帧方向计算旋转角度
    rotateAngle = 0;
    switch(_outputImageOrientation)
    {
        case UIInterfaceOrientationPortraitUpsideDown:
            rotateAngle = 180;
            break;
        case UIInterfaceOrientationLandscapeLeft:
            rotateAngle = 90;
            break;
        case UIInterfaceOrientationLandscapeRight:
            rotateAngle = -90;
            break;
        case UIInterfaceOrientationPortrait:
        default:
            rotateAngle = 0;
    }
    
    AVCaptureVideoOrientation orientation = AVCaptureVideoOrientationPortrait;
    if (_cameraPosition == AVCaptureDevicePositionFront) {
        orientation = _frontVideoOrientation;
    }
    else if (_cameraPosition == AVCaptureDevicePositionBack) {
        orientation = _backVideoOrientation;
    }
    
    switch(orientation)
    {
        case AVCaptureVideoOrientationPortraitUpsideDown:
            rotateAngle += 180;
            break;
        case AVCaptureVideoOrientationLandscapeLeft:
            rotateAngle -= 90;
            break;
        case AVCaptureVideoOrientationLandscapeRight:
            rotateAngle += 90;
            break;
        case AVCaptureVideoOrientationPortrait:
        default:
            rotateAngle += 0;
            break;
    }
    
    [self setFrameVertical:bufferInput];
    if (_cameraPosition==AVCaptureDevicePositionFront) {
        streamFrame->m_camera_position = GPU_CAMERA_FRONT;
        [self setMirrorFrontPreview:_mirrorFrontPreview];
        [self setMirrorFrontFacingCamera:_mirrorFrontFacingCamera];
    }
    else if (_cameraPosition==AVCaptureDevicePositionBack) {
        streamFrame->m_camera_position = GPU_CAMERA_BACK;
        [self setMirrorBackPreview:_mirrorBackPreview];
        [self setMirrorBackFacingCamera:_mirrorBackFacingCamera];
    }
}

-(void)setFrameVertical:(GPUInput*)input{
    if (_cameraPosition==AVCaptureDevicePositionBack) {
        switch(rotateAngle)
        {
            case 0:
            case 360:
                input->setOutputRotation(GPUNoRotation); break;
            case 90:
                input->setOutputRotation(GPURotateRight); break;
            case -90:
                input->setOutputRotation(GPURotateLeft); break;
            case 180:
            case -180:
                input->setOutputRotation(GPURotate180); break;
            default:input->setOutputRotation(GPUNoRotation);
        }
    }
    else{
        switch(rotateAngle)
        {
            case 0:
            case 360:
                input->setOutputRotation(GPUNoRotation); break;
            case 90:
                input->setOutputRotation(GPURotateLeft); break;
            case -90:
                input->setOutputRotation(GPURotateRight); break;
            case 180:
            case -180:
                input->setOutputRotation(GPURotate180); break;
            default:input->setOutputRotation(GPUNoRotation);
        }
    }
    
    //    if (_cameraPosition==AVCaptureDevicePositionBack) {
    //        switch(_outputImageOrientation)
    //        {
    //            case UIInterfaceOrientationPortrait:
    //                input->setOutputRotation(GPURotateRight); break;
    //            case UIInterfaceOrientationPortraitUpsideDown:
    //                input->setOutputRotation(GPURotateRight); break;
    //            case UIInterfaceOrientationLandscapeLeft:
    //                input->setOutputRotation(GPURotate180); break;
    //            case UIInterfaceOrientationLandscapeRight:
    //                input->setOutputRotation(GPUNoRotation); break;
    //            default:input->setOutputRotation(GPUNoRotation);
    //        }
    //    }
    //    else{
    //        switch(_outputImageOrientation){
    //            case UIInterfaceOrientationPortrait:
    //                input->setOutputRotation(GPURotateRight);break;
    //            case UIInterfaceOrientationPortraitUpsideDown:
    //                input->setOutputRotation(GPURotateLeft);break;
    //            case UIInterfaceOrientationLandscapeLeft:
    //                input->setOutputRotation(GPUNoRotation);break;
    //            case UIInterfaceOrientationLandscapeRight:
    //                input->setOutputRotation(GPURotate180);break;
    //            default:input->setOutputRotation(GPUNoRotation);
    //        }
    //    }
}

-(void)setOutputImageOrientation:(UIInterfaceOrientation)outputImageOrientation{
    _outputImageOrientation = outputImageOrientation;
    [self setCameraPosition:_cameraPosition];
}

-(void)setFrontVideoOrientation:(AVCaptureVideoOrientation)frontVideoOrientation{
    _frontVideoOrientation = frontVideoOrientation;
    if (_cameraPosition!=AVCaptureDevicePositionFront) {
        return;
    }
    [self setCameraPosition:_cameraPosition];
}
-(void)setBackVideoOrientation:(AVCaptureVideoOrientation)backVideoOrientation{
    _backVideoOrientation = backVideoOrientation;
    if (_cameraPosition!=AVCaptureDevicePositionBack) {
        return;
    }
    [self setCameraPosition:_cameraPosition];
}

-(void)setMirrorFrontFacingCamera:(BOOL)mirrorFrontFacingCamera{
    _mirrorFrontFacingCamera = mirrorFrontFacingCamera;
    if (_cameraPosition!=AVCaptureDevicePositionFront) {
        return;
    }
    if(_rawPixelBlock!=nil){
        if (_mirrorFrontFacingCamera) {
            rawFilter.setOutputRotation(GPUFlipHorizonal);
        }
        else{
            rawFilter.setOutputRotation(GPUNoRotation);
        }
    }
    streamFrame->setOutputMirror(_mirrorFrontFacingCamera);
    [self setVideoSize];
}

-(void)setMirrorBackFacingCamera:(BOOL)mirrorBackFacingCamera{
    _mirrorBackFacingCamera = mirrorBackFacingCamera;
    if (_cameraPosition!=AVCaptureDevicePositionBack) {
        return;
    }
    if(_rawPixelBlock!=nil){
        if (_mirrorBackFacingCamera) {
            rawFilter.setOutputRotation(GPUFlipHorizonal);
        }
        else{
            rawFilter.setOutputRotation(GPUNoRotation);
        }
    }
    streamFrame->setOutputMirror(_mirrorBackFacingCamera);
    [self setVideoSize];
}

-(void)setVideoSize{
//    switch(_outputImageOrientation)
//    {
//        case UIInterfaceOrientationPortrait:
//        case UIInterfaceOrientationPortraitUpsideDown:
//            _videoSize = CGSizeMake(originSize.height, originSize.width);
//            break;
//        case UIInterfaceOrientationLandscapeLeft:
//        case UIInterfaceOrientationLandscapeRight:
//        default:_videoSize = CGSizeMake(originSize.width, originSize.height);
//    }
    switch(rotateAngle)
    {
        case 90:
        case -90:
            _videoSize = CGSizeMake(originSize.height, originSize.width);
            break;
        case 0:
        case 360:
        case 180:
        case -180:
        default:
            _videoSize = CGSizeMake(originSize.width, originSize.height);
    }
    bufferInput->setOutputSize(_videoSize.width, _videoSize.height);
}

-(void)setMirrorFrontPreview:(BOOL)mirrorFrontPreview{
    _mirrorFrontPreview = mirrorFrontPreview;
    if (_cameraPosition!=AVCaptureDevicePositionFront || _preview==nil) {
        return;
    }
    
    streamFrame->setPreviewMirror(_mirrorFrontPreview);
}

-(void)setMirrorBackPreview:(BOOL)mirrorBackPreview{
    _mirrorBackPreview = mirrorBackPreview;
    if (_cameraPosition!=AVCaptureDevicePositionBack || _preview==nil) {
        return;
    }
    
    streamFrame->setPreviewMirror(_mirrorBackPreview);
}

#pragma -mark 输出视频流
-(void)setPreviewRotation:(gpu_rotation_t)previewRotation{
    _previewRotation = previewRotation;
    streamFrame->setPreviewRotation(previewRotation);
}
-(void)setOutputRotation:(gpu_rotation_t)outputRotation{
    _outputRotation = outputRotation;
    streamFrame->setOutputRotation(outputRotation);
}
-(void)setFrameRotation:(gpu_rotation_t)frameRotation{
    _frameRotation = frameRotation;
    streamFrame->setFrameRotation(frameRotation);
}

-(void)setOutputFillMode:(gpu_fill_mode_t)outputFillMode{
    _outputFillMode = outputFillMode;
    streamFrame->m_zoom_filter.setFillMode(outputFillMode);
}
-(void)setOutputSize:(CGSize)outputSize{
    _outputSize = outputSize;
    streamFrame->setOutputSize(outputSize.width, outputSize.height);
}

-(void)setBgraBytesBlock:(void (^)(unsigned char * ,int,int))bgraBytesBlock{
    _bgraBytesBlock = bgraBytesBlock;
    _nv21BytesBlock = nil;
    _nv12BytesBlock = nil;
    streamFrame->setOutputFormat(GPU_BGRA);
}

-(void)setNv21BytesBlock:(void (^)(unsigned char *,int,int))nv21BytesBlock{
    _bgraBytesBlock = nil;
    _nv21BytesBlock = nv21BytesBlock;
    _nv12BytesBlock = nil;
    streamFrame->setOutputFormat(GPU_NV21);
}

-(void)setNv12BytesBlock:(void (^)(unsigned char *,int,int))nv12BytesBlock{
    _bgraBytesBlock = nil;
    _nv21BytesBlock = nil;
    _nv12BytesBlock = nv12BytesBlock;
    streamFrame->setOutputFormat(GPU_NV12);
}

-(void)setRawPixelBlock:(void (^)(CVPixelBufferRef, CMTime))rawPixelBlock{
    _rawPixelBlock = rawPixelBlock;
    rawFilter.setOutputFormat(GPU_BGRA);
    bufferInput->addTarget(&rawFilter);
    if (_cameraPosition==AVCaptureDevicePositionFront && _mirrorFrontFacingCamera) {
        rawFilter.setOutputRotation(GPUFlipHorizonal);
    }
    else if(_cameraPosition==AVCaptureDevicePositionBack && _mirrorBackFacingCamera){
        rawFilter.setOutputRotation(GPUFlipHorizonal);
    }
    else{
        rawFilter.setOutputRotation(GPUNoRotation);
    }
}

-(void)setBgraPixelBlock:(void (^)(CVPixelBufferRef, CMTime))bgraPixelBlock{
    _bgraPixelBlock = bgraPixelBlock;
    _yuv420pPixelBlock = nil;
    _nv21PixelBlock = nil;
    _nv12PixelBlock = nil;
    _textureBlock = nil;
    streamFrame->setOutputFormat(GPU_BGRA);
}

-(void)setYuv420pPixelBlock:(void (^)(unsigned char *, CMTime))yuv420pPixelBlock{
    _bgraPixelBlock = nil;
    _yuv420pPixelBlock = yuv420pPixelBlock;
    _nv21PixelBlock = nil;
    _nv12PixelBlock = nil;
    _textureBlock = nil;
    streamFrame->setOutputFormat(GPU_I420);
}
-(void)setNv21PixelBlock:(void (^)(unsigned char *, CMTime))nv21PixelBlock{
    _bgraPixelBlock = nil;
    _yuv420pPixelBlock = nil;
    _nv21PixelBlock = nv21PixelBlock;
    _nv12PixelBlock = nil;
    _textureBlock = nil;
    streamFrame->setOutputFormat(GPU_NV21);
}
-(void)setNv12PixelBlock:(void (^)(unsigned char *, CMTime))nv12PixelBlock{
    _bgraPixelBlock = nil;
    _yuv420pPixelBlock = nil;
    _nv21PixelBlock = nil;
    _nv12PixelBlock = nv12PixelBlock;
    _textureBlock = nil;
    streamFrame->setOutputFormat(GPU_NV12);
}

-(void)setTextureBlock:(void (^)(unsigned int, CMTime))textureBlock{
    _bgraPixelBlock = nil;
    _yuv420pPixelBlock = nil;
    _nv21PixelBlock = nil;
    _nv12PixelBlock = nil;
    streamFrame->setOutputFormat(GPU_RGBA);
    _textureBlock = textureBlock;
}

-(void)dealloc{
    [self destroy];
}

-(void)destroy{
    if(bufferInput!=NULL){
        DELETE_SET_NULL(bufferInput, false);
        DELETE_SET_NULL(rawInput, false);
        DELETE_SET_NULL(playView, false);
        DELETE_SET_NULL(background, false);
        GPUStreamFrame::destroyInstance();
        GPUVertexBufferCache::destroyInstance();
        GPUBufferCache::destroyInstance();
        GPUContext::destroyInstance();
    }
}

#pragma --mark 美颜相关
-(void)setSmoothStrength:(float)smoothStrength{
    _smoothStrength = smoothStrength;
    streamFrame->setSmoothStrength(smoothStrength);
}
-(void)setWhitenStrength:(float)whitenStrength{
    _whitenStrength = whitenStrength;
    streamFrame->setWhitenStrength(whitenStrength);
}

#pragma --mark 额外滤镜
-(void)setExtraFilter:(NSString*)filterName{
    //NSString* path = [[NSBundle mainBundle] pathForResource:filterName ofType:@"png"];
    streamFrame->setExtraFilter([filterName UTF8String]);
}
-(void)closeExtraFilter{
    streamFrame->removeExtraFilter();
}
-(void)setExtraParameter:(float)para{
    streamFrame->setExtraParameter(para);
}

#pragma --mark "blend"
// 为preview叠加图片，例如添加logo
-(void)setPreviewBlend:(UIImage*)image rect:(CGRect)rect mirror:(BOOL)mirror{
    GPUStreamFrame* stream = GPUStreamFrame::shareInstance();
    GPUPicture* pic = new GPUPicture(image.CGImage);
    gpu_rect_t gpu_rect;
    gpu_rect.pointer.x = rect.origin.x;
    gpu_rect.pointer.y = rect.origin.y;
    gpu_rect.size.width = rect.size.width;
    gpu_rect.size.height = rect.size.height;
    stream->setPreviewBlend(pic, gpu_rect, mirror);
}
-(void)setPreviewBlend:(unsigned char*)bytes width:(int)w height:(int)h rect:(CGRect)rect mirror:(BOOL)mirror{
    GPUStreamFrame* stream = GPUStreamFrame::shareInstance();
    GPUPicture* pic = new GPUPicture(bytes, w, h);
    gpu_rect_t gpu_rect;
    gpu_rect.pointer.x = rect.origin.x;
    gpu_rect.pointer.y = rect.origin.y;
    gpu_rect.size.width = rect.size.width;
    gpu_rect.size.height = rect.size.height;
    stream->setPreviewBlend(pic, gpu_rect, mirror);
}
-(void)removePreviewBlend;{
    GPUStreamFrame* stream = GPUStreamFrame::shareInstance();
    gpu_rect_t rect = {0};
    stream->setPreviewBlend(NULL, rect, false);
}
// 为视频流叠加图片
-(void)setVideoBlend:(UIImage*)image rect:(CGRect)rect mirror:(BOOL)mirror{
    GPUStreamFrame* stream = GPUStreamFrame::shareInstance();
    GPUPicture* pic = new GPUPicture(image.CGImage);
    gpu_rect_t gpu_rect;
    gpu_rect.pointer.x = rect.origin.x;
    gpu_rect.pointer.y = rect.origin.y;
    gpu_rect.size.width = rect.size.width;
    gpu_rect.size.height = rect.size.height;
    stream->setVideoBlend(pic, gpu_rect, mirror);
}
-(void)setVideoBlend:(unsigned char*)bytes width:(int)w height:(int)h rect:(CGRect)rect mirror:(BOOL)mirror{
    GPUStreamFrame* stream = GPUStreamFrame::shareInstance();
    GPUPicture* pic = new GPUPicture(bytes, w, h);
    gpu_rect_t gpu_rect;
    gpu_rect.pointer.x = rect.origin.x;
    gpu_rect.pointer.y = rect.origin.y;
    gpu_rect.size.width = rect.size.width;
    gpu_rect.size.height = rect.size.height;
    stream->setVideoBlend(pic, gpu_rect, mirror);
}

-(void)removeVideoBlend;{
    GPUStreamFrame* stream = GPUStreamFrame::shareInstance();
    gpu_rect_t rect = {0};
    stream->setVideoBlend(NULL, rect, false);
}

# pragma --mark "边框"
-(void)setFrameSize:(CGSize)size{
    streamFrame->setStreamFrameSize(size.width, size.height);
}
// 添加边框
-(void)setBlank:(int)blank color:(UIColor*)color{
    if (color==NULL) {
        color = [UIColor whiteColor];
    }
    CGFloat r,g,b,a;
    [color getRed:&r green:&g blue:&b alpha:&a];
    streamFrame->setBlank(blank, r*255, g*255, b*255);
}

-(void)setColorFilter:(int)filter strength:(float)strength{
    switch(filter){
        case GPU_COLOR_CONTRAST_FILTER:
            streamFrame->m_color_filter.setContrast(strength);
            break;
        case GPU_COLOR_GAMMA_FILTER:
            streamFrame->m_color_filter.setGamma(strength);
            break;
        case GPU_COLOR_SATURATION_FILTER:
            streamFrame->m_color_filter.setSaturation(strength);
            break;
        case GPU_COLOR_FADE_FILTER:
            streamFrame->m_color_filter.setFade(strength);
            break;
        case GPU_COLOR_BLUR_FILTER:
            streamFrame->m_color_filter.setBlur(strength);
            break;
        case GPU_COLOR_SHARPNESS_FILTER:
            streamFrame->m_color_filter.setSharpness(strength);
            break;
        case GPU_COLOR_TEMPERATURE_FILTER:
            streamFrame->m_color_filter.setTemperature(strength);
            break;
        case GPU_COLOR_TINT_FILTER:
            streamFrame->m_color_filter.setTint(strength);
            break;
        case GPU_COLOR_HIGHLIGHTS_FILTER:
            streamFrame->m_color_filter.setHighlights(strength);
            break;
        case GPU_COLOR_SHADOWS_FILTER:
            streamFrame->m_color_filter.setShadows(strength);
            break;
        case GPU_COLOR_VIGNETTE_FILTER:
            streamFrame->m_color_filter.setVignette(strength);
            break;
        default:
            err_log("unkown color filter: %d", filter);
    }
}

-(void)setUnBlurRegion:(CGPoint)center radius:(int)radius{
    streamFrame->m_color_filter.setUnBlurRegion(center.x, center.y, radius);
}

#pragma --mark "预览模式"
-(void)setPreviewFillMode:(gpu_fill_mode_t)previewFillMode{
    _previewFillMode = previewFillMode;
    if (playView!=nil) {
        ((GPUUIView*)playView->uiview()).fillMode = previewFillMode;
    }
}
-(void)setPreviewSize:(CGSize)previewSize{
    _previewSize = previewSize;
    GPUStreamFrame::shareInstance()->m_preview_blend_filter.setOutputSize(previewSize.width, previewSize.height);
}
-(void)setPreviewColor:(UIColor*)color{
    if(playView != nil){
        ((GPUUIView*)playView->uiview()).previewColor = color;
    }
}

@end
