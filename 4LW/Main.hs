module Main where
import Machine
import Control.Monad.State.Lazy
import Control.Lens hiding (argument)
import Data.Maybe
import Data.Ix
import Base27
import Memory
import Instruction
import Registers
import qualified WordSequence
import qualified Tapes

import System.Environment
import Control.Applicative
import Options.Applicative


sanitizeProg :: [Char] -> [Char]
sanitizeProg = filter Base27.isLetter

data RunOptions = RunOptions { filename :: String
                             , tickTime:: Int
                             --, tapeFiles :: [(Letter, String)]
                             tapeFile :: Maybe String
                             } deriving (Show)

parseOptions :: Parser RunOptions
parseOptions = RunOptions
                   <$> strArgument (metavar "FILE")
                   <*> option auto (short 't' <> value 1000)
                   <*> (many $ option auto (short 'q' <> value (letter 'A', "wow")))

optionsAndInfo :: ParserInfo RunOptions
optionsAndInfo = info (helper <*> parseOptions)
    (fullDesc <> progDesc "4LW is a virtual machine implementing a base-27 architecture.")

main :: IO ()
main = do
  --let (_, state) = runState tick blankState
  options <- execParser optionsAndInfo

  prog <- readFile (filename options)

  let statemem = memory %~ fromJust . importString (sanitizeProg prog) minWord $ blankState
  let state = tapeDeck . at (letter 'A') .~ Just Tapes.blankTape $ statemem
  (_, state') <- runStateT (start (tickTime options)) state
  putStrLn "\n\n\n\n\n\n"
  putStrLn "Done:"
  putStrLn $ exportString (_memory state') (minWord, wrd "_AAA")

  putStrLn "Registers:"
  print $ state' ^. registers

  putStr "PC was at: "
  print $ fromJust $ state' ^? registers . ix pcRegister

  putStr "Ticks: "
  print $ state' ^. tickNum
