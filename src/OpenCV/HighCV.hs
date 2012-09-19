-- |High-level Haskell bindings to OpenCV operations. Some of these
-- operations will be performed in-place under composition. For
-- example, @dilate 8 . erode 8@ will allocate one new image rather
-- than two.
module AI.CV.OpenCV.HighCV (
                            -- * Image Files
                            fromFile, fromFileGray, fromFileColor, 
                            fromPGM16, toFile,
                            -- * Image Properties
                            width, height, numPixels, isColor, isMono,
                            -- * Image Construction
                            fromPixels, fromGrayPixels, fromColorPixels, 
                            fromPtr,
                            -- * Image Data Accessors
                            pixels, withPixelVector, withImagePixels, 
                            sampleLine, getRect,
                            -- * Image Processing
                            erode, dilate, houghStandard, houghProbabilistic, 
                            normalize, resize, setROI, resetROI,
                            module AI.CV.OpenCV.ColorConversion,
                            module AI.CV.OpenCV.Threshold,
                            module AI.CV.OpenCV.FloodFill,
                            module AI.CV.OpenCV.FeatureDetection,
                            Connectivity(..), 
                            CvRect(..), liftCvRect,
                            cv_L2, cv_MinMax, 
                            InterpolationMethod(..), 
                            -- * GUI and Drawing
                            module AI.CV.OpenCV.GUI, 
                            module AI.CV.OpenCV.Drawing,
                            -- * Video
                            module AI.CV.OpenCV.Video,
                            -- * Image types
                            HIplImage, Monochromatic, Trichromatic, 
                            HasChannels, HasDepth, 
                            GrayImage, ColorImage, GrayImage16, GrayImage16S,
                            Word8, Word16
    ) where
import AI.CV.OpenCV.Core.CxCore
import AI.CV.OpenCV.Core.CV
import AI.CV.OpenCV.Drawing
import AI.CV.OpenCV.Core.HIplUtil
import AI.CV.OpenCV.Core.CVOp
import AI.CV.OpenCV.ColorConversion
import Data.Word (Word8, Word16)
import Foreign.C.Types (CDouble)
import Foreign.Ptr
import Foreign.Storable
import System.IO.Unsafe (unsafePerformIO)
import AI.CV.OpenCV.GUI
import AI.CV.OpenCV.Threshold
import AI.CV.OpenCV.FloodFill
import AI.CV.OpenCV.FeatureDetection
import AI.CV.OpenCV.Video

-- |Erode an 'HIplImage' with a 3x3 structuring element for the
-- specified number of iterations.
erode :: (HasChannels c, HasDepth d, Inplace r c d c d) =>
         Int -> HIplImage c d r -> HIplImage c d r
erode n = cv2 $ \src dst -> cvErode src dst (fromIntegral n)
{-# INLINE erode #-}

-- |Dilate an 'HIplImage' with a 3x3 structuring element for the
-- specified number of iterations.
dilate :: (HasChannels c, HasDepth d, Inplace r c d c d) =>
          Int -> HIplImage c d r -> HIplImage c d r
dilate n = cv2 $ \src dst -> cvDilate src dst (fromIntegral n)
{-# INLINE dilate #-}

-- |Extract all the pixel values from an image along a line, including
-- the end points. Parameters are the two endpoints, the line
-- connectivity to use when sampling, and an image; returns the list
-- of pixel values.
sampleLine :: (HasChannels c, HasDepth d, ImgBuilder r) =>
              (Int, Int) -> (Int, Int) -> Connectivity -> HIplImage c d r -> [d]
sampleLine pt1 pt2 conn img = unsafePerformIO . withHIplImage img $ 
                                \p -> cvSampleLine p pt1 pt2 conn
{-# NOINLINE sampleLine #-}

-- |Line detection in a binary image using a standard Hough
-- transform. Parameters are @rho@, the distance resolution in
-- pixels; @theta@, the angle resolution in radians; @threshold@, the
-- line classification accumulator threshold; and the input image.
houghStandard :: ImgBuilder r =>
                 Double -> Double -> Int -> HIplImage Monochromatic Word8 r -> 
                 [((Int, Int),(Int,Int))]
houghStandard rho theta threshold img = unsafePerformIO $
    do storage <- cvCreateMemStorage (min 0 (fromIntegral threshold))
       cvSeq <- withHIplImage img $ 
                \p -> cvHoughLines2 p storage 0 rho theta threshold 0 0
       hlines <- mapM (\p -> do f1 <- peek p
                                f2 <- peek (plusPtr p (sizeOf (undefined::Float)))
                                return (f1,f2))
                      =<< seqToPList cvSeq
       cvReleaseMemStorage storage
       return $ map lineToSeg hlines
    where lineToSeg :: (Float,Float) -> ((Int,Int),(Int,Int))
          lineToSeg (rho, theta) = let a = cos theta
                                       b = sin theta
                                       x0 = a * rho
                                       y0 = b * rho
                                       x1 = clampX $ x0 + 10000*(-b)
                                       y1 = clampY $ y0 + 10000*a
                                       x2 = clampX $ x0 - 10000*(-b)
                                       y2 = clampY $ y0 - 10000*a
                                   in ((x1,y1),(x2,y2))
          w = fromIntegral (width img)
          h = fromIntegral (height img)
          clampX x = max 0 (min (truncate x) (w - 1))
          clampY y = max 0 (min (truncate y) (h - 1))
{-# NOINLINE houghStandard #-}

-- |Line detection in a binary image using a probabilistic Hough
-- transform. Parameters are @rho@, the distance resolution in pixels;
-- @theta@, the angle resolution in radians; @threshold@, the line
-- classification accumulator threshold; and the input image.
houghProbabilistic :: ImgBuilder r =>
                      Double -> Double -> Int -> Double -> Double -> 
                      HIplImage Monochromatic Word8 r -> [((Int, Int),(Int,Int))]
houghProbabilistic rho theta threshold minLength maxGap img = 
    unsafePerformIO $
    do storage <- cvCreateMemStorage (min 0 (fromIntegral threshold))
       cvSeq <- fmap snd . withDuplicateImage img $
                  \p -> cvHoughLines2 p storage 1 rho theta threshold
                                      minLength maxGap
       hlines <- mapM (\p1 -> do x1 <- peek p1
                                 let p2 = plusPtr p1 step
                                     p3 = plusPtr p2 step
                                     p4 = plusPtr p3 step
                                 y1 <- peek p2
                                 x2 <- peek p3
                                 y2 <- peek p4
                                 return ((x1,y1),(x2,y2)))
                      =<< seqToPList cvSeq
       cvReleaseMemStorage storage
       return hlines
    where step = sizeOf (undefined::Int)
{-# NOINLINE houghProbabilistic #-}

{-
-- |Find the 'CvContour's in an image.
findContours :: HIplImage a Monochromatic Word8 -> [CvContour]
findContours img = snd $ withDuplicateImage img $
                     \src -> cvFindContours src CV_RETR_CCOMP CV_CHAIN_APPROX_SIMPLE
-}

-- FIXME: There is no fusion mechanism that can handle 'resize'. The
-- problem is that the fusion combinators assume the output image is
-- the same size as the input image as this information is not
-- captured in the type. That said, it would be nice to be able to do
-- in-place updates to the output of 'resize'.

-- |Resize the supplied 'HIplImage' to the given width and height using
-- the supplied 'InterpolationMethod'.
resize :: (HasChannels c, HasDepth d) => 
          InterpolationMethod -> Int -> Int -> HIplImage c d NoROI -> 
          HIplImage c d NoROI
resize method w h img = 
    unsafePerformIO $
    do img' <- mkHIplImage w h
       _ <- withHIplImage img $ \src ->
              withHIplImage img' $ \dst ->
                cvResize src dst method
       return img'
{-# NOINLINE resize #-}

-- |Normalize the range of color values in an image to the given
-- range. Example usage with a grayscale image is @normalize cv_MinMax
-- 0 255 img@
normalize :: (HasChannels c, HasDepth d, Inplace r c d c d) => 
             ArrayNorm -> CDouble -> CDouble -> HIplImage c d r -> HIplImage c d r
normalize ntype a b = cv2 $ \img dst -> 
                      cvNormalize img dst a b (unNorm ntype) nullPtr
{-# INLINE normalize #-}
             
