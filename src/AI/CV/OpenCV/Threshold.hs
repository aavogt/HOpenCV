{-# LANGUAGE ForeignFunctionInterface, ScopedTypeVariables #-}
-- |Image thresholding operations. These operations will perform
-- destructive, in-place updates when composed with a producer of
-- fresh images.
module AI.CV.OpenCV.Threshold (thresholdBinary, thresholdBinaryInv,
                               thresholdTruncate, 
                               thresholdToZero, thresholdToZeroInv,
                               thresholdBinaryOtsu, thresholdBinaryOtsuInv,
                               thresholdTruncateOtsu, 
                               thresholdToZeroOtsu, thresholdToZeroOtsuInv) where
import Control.Arrow (second)
import Data.Bits ((.|.))
import Data.Word (Word8)
import Foreign.C.Types (CDouble, CInt)
import Foreign.Ptr (Ptr, castPtr)
import Foreign.Storable (Storable)
import System.IO.Unsafe (unsafePerformIO)
import AI.CV.OpenCV.Core.CxCore 
import AI.CV.OpenCV.Core.HIplUtils

data ThresholdType = ThreshBinary
                   | ThreshBinaryInv
                   | ThreshTrunc
                   | ThreshToZero
                   | ThreshToZeroInv
                     deriving Enum

foreign import ccall unsafe "opencv/cv.h cvThreshold"
  c_cvThreshold :: Ptr CvArr -> Ptr CvArr -> CDouble -> CDouble -> CInt -> 
                   IO (CDouble)

-- The worker function that calls c_cvThreshold.
cvThreshold :: (ByteOrFloat d, HasDepth d, Storable d) =>
               d -> d -> Int -> HIplImage a MonoChromatic d ->
               (HIplImage FreshImage MonoChromatic d, d)
cvThreshold threshold maxValue tType src = 
    unsafePerformIO $
    withHIplImage src $ \srcPtr ->
      cvtResult . withCompatibleImage src $ \dstPtr -> 
                    c_cvThreshold (castPtr srcPtr) (castPtr dstPtr) 
                                  threshold' maxValue' tType'
    where threshold' = realToFrac . toDouble $ threshold
          maxValue' = realToFrac . toDouble $ maxValue
          tType' = fromIntegral tType
          cvtResult = return . second (fromDouble . realToFrac)

cvThreshold1 :: (ByteOrFloat d, HasDepth d, Storable d) =>
               d -> d -> Int -> HIplImage a MonoChromatic d ->
               HIplImage FreshImage MonoChromatic d
cvThreshold1 threshold maxValue tType src = 
    fst $ cvThreshold threshold maxValue tType src

unsafeCvThreshold :: (ByteOrFloat d, HasDepth d, Storable d) =>
                      d -> d -> Int -> HIplImage FreshImage MonoChromatic d ->
                      (HIplImage FreshImage MonoChromatic d, d)
unsafeCvThreshold threshold maxValue tType src = 
    unsafePerformIO $
    withHIplImage src $ \srcPtr ->
      do r <- c_cvThreshold (castPtr srcPtr) (castPtr srcPtr) 
                             threshold' maxValue' tType'
         return (src, fromDouble (realToFrac r))
    where threshold' = realToFrac . toDouble $ threshold
          maxValue' = realToFrac . toDouble $ maxValue
          tType' = fromIntegral tType

unsafeCvThreshold1 :: (ByteOrFloat d, HasDepth d, Storable d) =>
                      d -> d -> Int -> HIplImage FreshImage MonoChromatic d ->
                      HIplImage FreshImage MonoChromatic d
unsafeCvThreshold1 th mv tt = fst . unsafeCvThreshold th mv tt

-- Use Otsu's method to determine an optimal threshold value which is
-- returned along with the thresholded image.
cvThresholdOtsu :: Word8 -> Int -> HIplImage a MonoChromatic Word8 ->
                   (HIplImage FreshImage MonoChromatic Word8, Word8)
cvThresholdOtsu maxValue tType = cvThreshold 0 maxValue tType'
    where otsu = 8
          tType' = tType .|. otsu

unsafeCvThresholdOtsu :: Word8 -> Int -> 
                         HIplImage FreshImage MonoChromatic Word8 ->
                         (HIplImage FreshImage MonoChromatic Word8, Word8)
unsafeCvThresholdOtsu maxValue tType = unsafeCvThreshold 0 maxValue tType'
    where otsu = 8
          tType' = tType .|. otsu

-- |Binary thresholding. Parameters are the @threshold@ value, the
-- @maxValue@ passing pixels are mapped to, and the source
-- 'HIplImage'. Each pixel greater than @threshold@ is mapped to
-- @maxValue@, while all others are mapped to zero.
thresholdBinary :: (ByteOrFloat d, HasDepth d, Storable d) =>
                   d -> d -> HIplImage a MonoChromatic d ->
                   HIplImage FreshImage MonoChromatic d
thresholdBinary th maxValue = cvThreshold1 th maxValue (fromEnum ThreshBinary)

-- |Inverse binary thresholding. Parameters are the @threshold@ value,
-- the @maxValue@ passing pixels are mapped to, and the source
-- 'HIplImage'. Each pixel greater than @threshold@ is mapped to zero,
-- while all others are mapped to @maxValue@.
thresholdBinaryInv :: (ByteOrFloat d, HasDepth d, Storable d) =>
                      d -> d -> HIplImage a MonoChromatic d ->
                      HIplImage FreshImage MonoChromatic d
thresholdBinaryInv th maxValue = cvThreshold1 th maxValue tType
    where tType = fromEnum ThreshBinaryInv

unsafeThreshBin :: (ByteOrFloat d, HasDepth d, Storable d) =>
                   d -> d -> HIplImage FreshImage MonoChromatic d ->
                   HIplImage FreshImage MonoChromatic d
unsafeThreshBin th maxValue = unsafeCvThreshold1 th maxValue tType
    where tType = fromEnum ThreshBinary

unsafeThreshBinInv :: (ByteOrFloat d, HasDepth d, Storable d) =>
                      d -> d -> HIplImage FreshImage MonoChromatic d ->
                      HIplImage FreshImage MonoChromatic d
unsafeThreshBinInv th maxValue = unsafeCvThreshold1 th maxValue tType
    where tType = fromEnum ThreshBinaryInv

{-# RULES "thresholdBinary/in-place"
  forall th mv (g::a -> HIplImage FreshImage MonoChromatic d).
  thresholdBinary th mv . g = unsafeThreshBin th mv . g
  #-}

{-# RULES "thresholdBinaryInv/in-place"
  forall th mv (g::a -> HIplImage FreshImage MonoChromatic d).
  thresholdBinaryInv th mv . g = unsafeThreshBinInv th mv . g
  #-}


-- |Truncation thresholding (i.e. clamping). Parameters are the
-- @threshold@ value and the source 'HIplImage'. Maps pixels that are
-- greater than @threshold@ to the @threshold@ value; leaves all other
-- pixels unchanged.
thresholdTruncate :: (ByteOrFloat d, HasDepth d, Storable d, Num d) => 
                     d -> HIplImage a MonoChromatic d ->
                     HIplImage FreshImage MonoChromatic d
thresholdTruncate threshold = cvThreshold1 threshold 0 (fromEnum ThreshTrunc)

unsafeThreshTrunc :: (ByteOrFloat d, HasDepth d, Storable d, Num d) => 
                     d -> HIplImage FreshImage MonoChromatic d ->
                     HIplImage FreshImage MonoChromatic d
unsafeThreshTrunc th = unsafeCvThreshold1 th 0 (fromEnum ThreshTrunc)

{-# RULES "thresholdTruncate/in-place"
  forall th (g::a -> HIplImage FreshImage MonoChromatic d).
  thresholdTruncate th . g = unsafeThreshTrunc th . g
  #-}

-- |Maps pixels that are less than or equal to @threshold@ to zero;
-- leaves all other pixels unchanged. Parameters the @threshold@ value
-- and the source 'HIplImage'.
thresholdToZero :: (ByteOrFloat d, HasDepth d, Storable d, Num d) => 
                   d -> HIplImage a MonoChromatic d ->
                   HIplImage FreshImage MonoChromatic d
thresholdToZero threshold = cvThreshold1 threshold 0 (fromEnum ThreshToZero)

-- |Maps pixels that are greater than @threshold@ to zero; leaves all
-- other pixels unchanged. Parameters the @threshold@ value and the
-- source 'HIplImage'.
thresholdToZeroInv :: (ByteOrFloat d, HasDepth d, Storable d, Num d) => 
                      d -> HIplImage a MonoChromatic d ->
                      HIplImage FreshImage MonoChromatic d
thresholdToZeroInv threshold = cvThreshold1 threshold 0 tType
    where tType = fromEnum ThreshToZeroInv

unsafeThresholdToZero :: (ByteOrFloat d, HasDepth d, Storable d, Num d) => 
                         d -> HIplImage FreshImage MonoChromatic d ->
                         HIplImage FreshImage MonoChromatic d
unsafeThresholdToZero th = unsafeCvThreshold1 th 0 tType
    where tType = fromEnum ThreshToZero

unsafeThresholdToZeroInv :: (ByteOrFloat d, HasDepth d, Storable d, Num d) => 
                         d -> HIplImage FreshImage MonoChromatic d ->
                         HIplImage FreshImage MonoChromatic d
unsafeThresholdToZeroInv th = unsafeCvThreshold1 th 0 tType
    where tType = fromEnum ThreshToZeroInv


{-# RULES "thresholdToZero/in-place" 
  forall th (g::a -> HIplImage FreshImage MonoChromatic d).
  thresholdToZero th . g = unsafeThresholdToZero th . g
  #-}

{-# RULES "thresholdToZeroInv/in-place" 
  forall th (g::a -> HIplImage FreshImage MonoChromatic d).
  thresholdToZeroInv th . g = unsafeThresholdToZeroInv th . g
  #-}


-- |Binary thresholding using Otsu's method to determine an optimal
-- threshold value. The chosen value is returned along with the
-- thresholded image. Takes the @maxValue@ to replace pixels that pass
-- the threshold with and the source 'HIplImage'.
thresholdBinaryOtsu :: Word8 -> HIplImage a MonoChromatic Word8 ->
                       (HIplImage FreshImage MonoChromatic Word8, Word8)
thresholdBinaryOtsu maxValue = cvThresholdOtsu maxValue tType
    where tType = fromEnum ThreshBinary

-- |Binary thresholding using Otsu's method to determine an optimal
-- threshold value. The chosen value is returned along with the
-- thresholded image. Takes the @maxValue@ to replace pixels that pass
-- the threshold with and the source 'HIplImage'. The sense of the
-- thresholding operation is inverted, as in 'thresholdBinaryInv'.
thresholdBinaryOtsuInv :: Word8 -> HIplImage a MonoChromatic Word8 ->
                          (HIplImage FreshImage MonoChromatic Word8, Word8)
thresholdBinaryOtsuInv maxValue = cvThresholdOtsu maxValue tType
    where tType = fromEnum ThreshBinaryInv

unsafeBinOtsu :: Word8 -> HIplImage FreshImage MonoChromatic Word8 ->
                 (HIplImage FreshImage MonoChromatic Word8, Word8)
unsafeBinOtsu maxValue = unsafeCvThresholdOtsu maxValue tType
    where tType = fromEnum ThreshBinary

unsafeBinOtsuInv :: Word8 -> HIplImage FreshImage MonoChromatic Word8 ->
                    (HIplImage FreshImage MonoChromatic Word8, Word8)
unsafeBinOtsuInv maxValue = unsafeCvThresholdOtsu maxValue tType
    where tType = fromEnum ThreshBinaryInv


{-# RULES "thresholdBinaryOtsu/in-place"
  forall mv (g::a -> HIplImage FreshImage MonoChromatic Word8).
  thresholdBinaryOtsu mv . g = unsafeBinOtsu mv . g
  #-}

{-# RULES "thresholdBinaryOtsuInv/in-place"
  forall mv (g::a -> HIplImage FreshImage MonoChromatic Word8).
  thresholdBinaryOtsuInv mv . g = unsafeBinOtsuInv mv . g
  #-}


-- |Maps pixels that are greater than @threshold@ to the @threshold@
-- value; leaves all other pixels unchanged. Takes the source
-- 'HIplImage'; the @threshold@ value is chosen using Otsu's method
-- and returned along with the thresholded image.
thresholdTruncateOtsu :: HIplImage a MonoChromatic Word8 -> 
                         (HIplImage FreshImage MonoChromatic Word8, Word8)
thresholdTruncateOtsu = cvThresholdOtsu 0 (fromEnum ThreshTrunc)

unsafeTruncOtsu :: HIplImage FreshImage MonoChromatic Word8 -> 
                   (HIplImage FreshImage MonoChromatic Word8, Word8)
unsafeTruncOtsu = unsafeCvThresholdOtsu 0 (fromEnum ThreshTrunc)

{-# RULES "thresholdTruncateOtsu/in-place"
  forall (g :: a -> HIplImage FreshImage MonoChromatic Word8).
  thresholdTruncateOtsu . g = unsafeTruncOtsu . g
  #-}

-- |Maps pixels that are less than or equal to @threshold@ to zero;
-- leaves all other pixels unchaged.The @threshold@ value is chosen
-- using Otsu's method and returned along with the thresholded image.
thresholdToZeroOtsu :: HIplImage a MonoChromatic Word8 -> 
                       (HIplImage FreshImage MonoChromatic Word8, Word8)
thresholdToZeroOtsu = cvThresholdOtsu 0 (fromEnum ThreshToZero)

-- |Maps pixels that are greather than @threshold@ to zero; leaves all
-- other pixels unchaged.The @threshold@ value is chosen using Otsu's
-- method and returned along with the thresholded image.
thresholdToZeroOtsuInv :: HIplImage a MonoChromatic Word8 -> 
                          (HIplImage FreshImage MonoChromatic Word8, Word8)
thresholdToZeroOtsuInv = cvThresholdOtsu 0 (fromEnum ThreshToZeroInv)

unsafeToZeroOtsu :: HIplImage FreshImage MonoChromatic Word8 -> 
                    (HIplImage FreshImage MonoChromatic Word8, Word8)
unsafeToZeroOtsu = unsafeCvThresholdOtsu 0 tType
    where tType = fromEnum ThreshToZero

unsafeToZeroOtsuInv :: HIplImage FreshImage MonoChromatic Word8 -> 
                       (HIplImage FreshImage MonoChromatic Word8, Word8)
unsafeToZeroOtsuInv = unsafeCvThresholdOtsu 0 tType
    where tType = fromEnum ThreshToZeroInv


{-# RULES "thresholdToZeroOtsu/in-place"
  forall (g :: a -> HIplImage FreshImage MonoChromatic Word8).
  thresholdToZeroOtsu . g = unsafeToZeroOtsu . g
  #-}

{-# RULES "thresholdToZeroOtsuInv/in-place"
  forall (g :: a -> HIplImage FreshImage MonoChromatic Word8).
  thresholdToZeroOtsuInv . g = unsafeToZeroOtsuInv . g
  #-}
