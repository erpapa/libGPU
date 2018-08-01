#ifndef	__GL_H_
#define	__GL_H_

#include <stdio.h>

// 裁剪方式
typedef enum{
    GPUFillModeStretch,                       // 完全匹配，直接拉伸
    GPUFillModePreserveAspectRatio,           // 适配输出尺寸，可能有边框
    GPUFillModePreserveAspectRatioAndFill     // 按照输出比例裁剪，不保留边框
}gpu_fill_mode_t;

// 视频帧格式
typedef enum{
    GPU_UNKNOWN = 0,
    GPU_RGBA = 1,
    GPU_NV21 = 2,
    GPU_I420 = 3,
    GPU_YV12 = 4,
    GPU_YUV444 = 5,
    GPU_NV12 = 6,
    GPU_BGRA = 7,
    GPU_GRAY = 8,
}gpu_pixel_format_t;

// texture类别，GPU_TEXTURE_OES只能用于安卓
typedef enum{
    GPU_TEXTURE_RGBA = 0,   // 默认纹理，属于非规范化纹理
    GPU_TEXTURE_OES = 1,    // 用于安卓oes类型texutre，实际是nv21格式
    GPU_TEXTURE_UNNORMAL,   // 非规范化纹理
    /* 以下是gles3.0中才有 */
    GPU_TEXTURE_NORMAL,     // 规范化纹理
    GPU_TEXTURE_FLOAT,      // 浮点纹理
    GPU_TEXTURE_INTEGER,    // 整数纹理
    GPU_TEXTURE_SHARED,     // 共享指数纹理
    GPU_TEXTURE_DEPTH,      // 深度纹理
    GPU_TEXTURE_SRGB        // sRGB纹理
}gpu_texture_type_t;

// 旋转方向，一般用于指定人脸方向，均为顺时针旋转
typedef enum{
    GPU_CLOCKWISE_0,
    GPU_CLOCKWISE_90,
    GPU_CLOCKWISE_180,
    GPU_CLOCKWISE_270,
}gpu_orientation_t;

typedef enum{
    GPU_CAMERA_BACK,
    GPU_CAMERA_FRONT
}gpu_camera_position_t;

// 指定输出texture的旋转方向
typedef enum{
    GPUNoRotation = 0,
    GPURotateLeft = 1,
    GPURotateRight = 2,
    GPUFlipVertical = 3,
    GPUFlipHorizonal = 4,
    GPURotateRightFlipVertical = 5,
    GPURotateRightFlipHorizontal = 6,
    GPURotate180 = 7,
}gpu_rotation_t;

typedef struct gpu_size_t{
    unsigned int    width;
    unsigned int    height;
}gpu_size_t;

typedef struct gpu_border_t {
    int left;	///< 矩形最左边的坐标
    int top;	///< 矩形最上边的坐标
    int right;	///< 矩形最右边的坐标
    int bottom;	///< 矩形最下边的坐标
} gpu_border_t;

typedef struct gpu_point_t{
    float x;
    float y;
}gpu_point_t;

typedef struct gpu_colori_t{
    unsigned char r;
    unsigned char g;
    unsigned char b;
    unsigned char a;
}gpu_colori_t;

typedef struct gpu_colorf_t{
    float r;
    float g;
    float b;
    float a;
}gpu_colorf_t;

typedef struct gpu_rect_t{
    gpu_point_t pointer;
    struct {
        float   width;
        float   height;
    }size;
}gpu_rect_t;

#endif
