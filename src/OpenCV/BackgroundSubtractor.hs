{-# LANGUAGE ForeignFunctionInterface #-}
-- | Interface to
-- <http://docs.opencv.org/modules/video/doc/motion_analysis_and_object_tracking.html#backgroundsubtractor>
module OpenCV.BackgroundSubtractor where

import OpenCV.Core.CxCore (IplImage)
import Foreign.C
import Foreign.Ptr

newtype BGS = BGS (Ptr BGS)
newtype BGS2 = BGS2 (Ptr BGS2)


foreign import ccall "initBGS"
  initBGS :: CInt -- ^ history
      -> CInt -- ^ nmixtures
      -> CDouble -- ^ background ratio
      -> CDouble -- ^ noise sigma
      -> IO BGS


foreign import ccall "learnBGS"
  learnBGS :: BGS
    -> Ptr IplImage -- ^ input
    -> Ptr IplImage -- ^ output (mask)
    -> CDouble -- ^ learning rate
    -> IO ()


foreign import ccall "initBGS2"
  initBGS2 :: CInt -- ^ history
    -> CInt -- ^ int nmixtures,
    -> CFloat -- ^ float backgroundRatio,
    -> CFloat -- ^ float varThreshold,
    -> CInt -- ^ int shadowDetection,
    -> CFloat -- ^ float varThresholdGen,
    -> CFloat -- ^ float fVarInit,
    -> CFloat -- ^ float fVarMin,
    -> CFloat -- ^ float fVarMax,
    -> CFloat -- ^ float fCT,
    -> CUChar -- ^ uchar nShadowDetection,
    -> CFloat -- ^ float fTau
    -> IO BGS2

foreign import ccall "learnBGS2"
  learnBGS2 :: BGS2
    -> Ptr IplImage -- ^ input
    -> Ptr IplImage -- ^ output (mask)
    -> CDouble -- ^ learning rate
    -> IO ()

foreign import ccall "getBackgroundImage"
  getBackgroundImage :: BGS
    -> Ptr IplImage
    -> IO ()

foreign import ccall "getBackgroundImage2"
  getBackgroundImage2 :: BGS2
    -> Ptr IplImage
    -> IO ()

foreign import ccall "freeBGS" freeBGS :: BGS -> IO ()
foreign import ccall "freeBGS2" freeBGS2 :: BGS2 -> IO ()
