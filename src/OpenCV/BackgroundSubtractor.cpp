

#include "opencv2/video/background_segm.hpp"
#include "opencv2/core/types_c.h"

// for whatever reason, fields set by setThings are protected in the
// BackgroundSubtractorMOG2 class, so this is how you're supposed to override
// them?
class backgroundsubtractormog2 : public cv::BackgroundSubtractorMOG2 {

  public:
    // shouldn't the superclass constructor get called automatically?
    backgroundsubtractormog2(int history, float varThreshold, int shadowDetection) {
      cv::BackgroundSubtractorMOG2(history, varThreshold, shadowDetection);
    }
    backgroundsubtractormog2() {
      cv::BackgroundSubtractorMOG2();
    }

    void setThings(
               int nmixtures,
               float backgroundRatio,
               float varThresholdGen,
               float fVarInit,
               float fVarMin,
               float fVarMax,
               float fCT,
               uchar nShadowDetection,
               float fTau) {
      this->nmixtures = nmixtures;
      this->backgroundRatio=backgroundRatio;
      this->varThresholdGen=varThresholdGen;
      this->fVarInit=fVarInit;
      this->fVarMin=fVarMin;
      this->fVarMax=fVarMax;
      this->fCT=fCT;
      this->nShadowDetection=nShadowDetection;
      this->fTau=fTau;
  };
};

extern "C" {
void* initBGS (int history, int nmixtures, double backgroundRatio, double noiseSigma) {
   cv::BackgroundSubtractorMOG *x = new cv::BackgroundSubtractorMOG(history,
                                      nmixtures,
                                      backgroundRatio,
                                      noiseSigma);
  return (void*) x;
};


void learnBGS (void* x, IplImage * image, IplImage * fgmask, double learningRate) {
  (*((cv::BackgroundSubtractorMOG *) x))( cv::Mat(image,false), cv::Mat(fgmask,false), learningRate);
};


void *  initBGS2 (int history, 
               int nmixtures,
               float backgroundRatio,
               float varThreshold,
               int shadowDetection,
               float varThresholdGen,
               float fVarInit,
               float fVarMin,
               float fVarMax,
               float fCT,
               uchar nShadowDetection,
               float fTau) {
  backgroundsubtractormog2 * y = new backgroundsubtractormog2(history, varThreshold, shadowDetection);
  y->setThings(nmixtures,backgroundRatio,varThresholdGen,fVarInit,fVarMin,fVarMax,
               fCT, nShadowDetection, fTau);
  return (void*) y;
};

void learnBGS2 (void* y, IplImage * image, IplImage * fgmask, double learningRate) {
  (* ((backgroundsubtractormog2 *) y ))( cv::Mat(image,false), cv::Mat(fgmask,false), learningRate);
  return;
};

void getBackgroundImage (void*x, IplImage * image) {
  ((cv::BackgroundSubtractorMOG *) x)->getBackgroundImage(cv::Mat(image, false));
};
void getBackgroundImage2 (void*y, IplImage * image) {
  ((backgroundsubtractormog2 *) y)->getBackgroundImage(cv::Mat(image, false));
};

void freeBGS( void* x ) {
  delete ((cv::BackgroundSubtractorMOG *) x);
};

void freeBGS2( void* y ) {
  delete ((backgroundsubtractormog2 *) y);
};
}
