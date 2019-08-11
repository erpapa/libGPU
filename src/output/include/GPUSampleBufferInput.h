/**
 * file :	GPUSampleBufferInput.h
 * author :	Rex
 * email : rex@labjk.com
 * create :	2017-03-25 20:41
 * func : 
 * history:
 */

#ifndef	__GPUSAMPLEBUFFERINPUT_H_
#define	__GPUSAMPLEBUFFERINPUT_H_

#include <Foundation/Foundation.h>
#include <AVFoundation/AVFoundation.h>
#include "GPU.h"
#include "GPUGroupFilter.h"
#include "GPUYUVFilter.h"
#include "GPUIOSBuffer.h"

class GPUSampleBufferInput: public GPUGroupFilter{
public:
    GPUSampleBufferInput();
    ~GPUSampleBufferInput();
    // 视频流处理
    void processSampleBuffer(CMSampleBufferRef sampleBuffer);
    void processPixelBuffer(CVImageBufferRef pixelBuffer);
    
    GPUIOSFrameBuffer*  m_rawbuffer;
protected:
    OSType              m_format;        // 是否YUV数据
};

#endif
