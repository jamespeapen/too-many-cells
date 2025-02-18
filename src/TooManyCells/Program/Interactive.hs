{- TooManyCells.Program.Interactive
Gregory W. Schwartz

Interactive entry point into program.
-}

{-# LANGUAGE QuasiQuotes       #-}
{-# LANGUAGE BangPatterns      #-}
{-# LANGUAGE DataKinds         #-}
{-# LANGUAGE DeriveGeneric     #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE PackageImports    #-}
{-# LANGUAGE TypeOperators     #-}
{-# LANGUAGE TupleSections     #-}
{-# LANGUAGE DuplicateRecordFields #-}

module TooManyCells.Program.Interactive where

-- Remote
import BirchBeer.Interactive
import BirchBeer.Load
import BirchBeer.Types
import Control.Monad (join)
import Control.Monad.Trans (liftIO)
import Data.Bool (bool)
import Data.Maybe (fromMaybe, isJust)
import Data.Tree (Tree (..))
import Language.R as R
import Math.Clustering.Hierarchical.Spectral.Types (getClusterItemsDend, EigenGroup (..))
import Math.Clustering.Spectral.Sparse (b1ToB2, B1 (..), B2 (..))
import qualified Control.Lens as L
import qualified Data.Aeson as A
import qualified Data.ByteString.Lazy.Char8 as B
import qualified Data.Vector as V
import qualified H.Prelude as H
import qualified System.Directory as FP
import qualified System.FilePath as FP

-- Local
import TooManyCells.File.Types
import TooManyCells.MakeTree.Types
import TooManyCells.MakeTree.Utility
import TooManyCells.Matrix.Types
import TooManyCells.Program.LoadMatrix
import TooManyCells.Program.Options
import TooManyCells.Program.Utility

-- | Interactive tree interface.
interactiveMain :: Subcommand -> IO ()
interactiveMain sub@(InteractiveCommand opts) = H.withEmbeddedR defaultConfig $ do
    let labelsFile'    =
            fmap LabelFile . (labelsFile :: Interactive -> Maybe String) $ opts
        prior'         = PriorPath . (prior :: Interactive -> String) $ opts
        updateTreeRows' =
          UpdateTreeRowsFlag . not . (noUpdateTreeRows :: Interactive -> Bool) $ opts
        delimiter'        = Delimiter
                          . (delimiter :: LoadMatrixOptions -> Char)
                          . (loadMatrixOptions :: Interactive -> LoadMatrixOptions)
                          $ opts

    scRes <- loadAllSSM sub
           $ (loadMatrixOptions :: Interactive -> LoadMatrixOptions) opts
    let mat = fmap fst scRes
        customLabelMap = join . fmap snd $ scRes

    labelMap <- if isJust labelsFile'
                  then mapM (loadLabelData delimiter') $ labelsFile'
                  else return customLabelMap

    tree <- fmap ( updateTreeRowBool updateTreeRows' mat
                 . either error id
                 . A.eitherDecode
                 )
          . B.readFile
          . (FP.</> "cluster_tree.json")
          . unPriorPath
          $ prior' :: IO (Tree (TreeNode (V.Vector CellInfo)))

    interactiveDiagram
        tree
        labelMap
        mat
        . fmap ( B2Matrix
               . L.over matrix (MatObsRow . unB2 . b1ToB2 . B1 . unMatObsRow)
               )
        $ mat

    return ()
interactiveMain _ = error "Wrong path in interactive, contact Gregory Schwartz for this error."
