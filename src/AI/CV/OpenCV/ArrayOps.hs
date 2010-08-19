{-# LANGUAGE ForeignFunctionInterface #-}
module AI.CV.OpenCV.ArrayOps (subRS, subRSVec, absDiff) where
import Foreign.C.Types (CDouble)
import Foreign.Ptr (Ptr, castPtr, nullPtr)
import Foreign.Storable (Storable)
import System.IO.Unsafe (unsafePerformIO)
import AI.CV.OpenCV.CxCore (CvArr)
import AI.CV.OpenCV.HIplUtils

foreign import ccall unsafe "opencv/cxcore.h cvSubRS"
  c_cvSubRS :: Ptr CvArr -> CDouble -> CDouble -> CDouble -> CDouble -> 
               Ptr CvArr -> Ptr CvArr -> IO ()

-- |Compute @value - src[i]@ for every pixel in the source 'HIplImage'.
subRS :: (HasDepth d, Storable d) =>
         d -> HIplImage a MonoChromatic d -> 
         HIplImage FreshImage MonoChromatic d
subRS value src = unsafePerformIO $ 
                  withHIplImage src $ \srcPtr ->
                    return . fst . withCompatibleImage src $ \dstPtr -> 
                      c_cvSubRS (castPtr srcPtr) v v v v (castPtr dstPtr) 
                                nullPtr
    where v = realToFrac . toDouble $ value

-- Unsafe in-place pointwise subtraction of each pixel from a given
-- scalar value.
unsafeSubRS :: (HasDepth d, Storable d) =>
               d -> HIplImage FreshImage MonoChromatic d ->
               HIplImage FreshImage MonoChromatic d
unsafeSubRS value src = unsafePerformIO $
                        withHIplImage src $ \srcPtr ->
                            do c_cvSubRS (castPtr srcPtr) v v v v 
                                         (castPtr srcPtr) nullPtr
                               return src
    where v = realToFrac . toDouble $ value

{-# RULES "subRS-in-place" forall v (f::a -> HIplImage FreshImage MonoChromatic d). 
    subRS v . f = unsafeSubRS v . f
  #-}

-- |Compute @value - src[i]@ for every pixel in the source 'HIplImage'.
subRSVec :: (HasDepth d, Storable d) =>
            (d,d,d) -> HIplImage a TriChromatic d ->
            HIplImage FreshImage TriChromatic d
subRSVec (r,g,b) src = unsafePerformIO $
                       withHIplImage src $ \src' ->
                         return . fst . withCompatibleImage src $ \dst' ->
                           c_cvSubRS (castPtr src') r' g' b' 0 (castPtr dst')
                                     nullPtr
    where r' = realToFrac . toDouble $ r
          g' = realToFrac . toDouble $ g
          b' = realToFrac . toDouble $ b

unsafeSubRSVec :: (HasDepth d, Storable d) =>
                  (d,d,d) -> HIplImage FreshImage TriChromatic d ->
                  HIplImage FreshImage TriChromatic d
unsafeSubRSVec (r,g,b) src = unsafePerformIO $
                             withHIplImage src $ \src' ->
                                 do c_cvSubRS (castPtr src') r' g' b' 0 
                                              (castPtr src') nullPtr
                                    return src
    where r' = realToFrac . toDouble $ r
          g' = realToFrac . toDouble $ g
          b' = realToFrac . toDouble $ b

{-# RULES "subRSVec-inplace" 
  forall v (g::a->HIplImage FreshImage TriChromatic d).
  subRSVec v . g = unsafeSubRSVec v . g
  #-}

foreign import ccall unsafe "opencv/cxcore.h cvAbsDiff"
  c_cvAbsDiff :: Ptr CvArr -> Ptr CvArr -> Ptr CvArr -> IO ()

-- |Calculate the absolute difference between two images.
absDiff :: (HasChannels c, HasDepth d, Storable d) => 
           HIplImage a c d -> HIplImage a c d -> HIplImage FreshImage c d
absDiff src1 src2 = unsafePerformIO $
                    withHIplImage src1 $ \src1' ->
                      withHIplImage src2 $ \src2' ->
                        return . fst . withCompatibleImage src1 $ \dst ->
                          c_cvAbsDiff (castPtr src1') (castPtr src2') 
                                      (castPtr dst)

unsafeAbsDiff :: (HasChannels c, HasDepth d, Storable d) => 
                 HIplImage a c d -> HIplImage FreshImage c d -> 
                 HIplImage FreshImage c d
unsafeAbsDiff src1 src2 = unsafePerformIO $
                          withHIplImage src1 $ \src1' ->
                            withHIplImage src2 $ \src2' ->
                                do c_cvAbsDiff (castPtr src1') (castPtr src2') 
                                               (castPtr src2')
                                   return src2

{-# RULES "absDiff-inplace"
  forall m1 (g::a -> HIplImage FreshImage c d). 
  absDiff m1 . g = unsafeAbsDiff m1 . g
  #-}