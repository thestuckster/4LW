{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE BangPatterns #-}
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
import qualified WordSequence as WS
import qualified Tapes
import qualified VMInterface

import System.Environment
import Control.Applicative
import Options.Applicative
import Text.Read
import Control.Exception
import System.IO


sanitizeProg :: [Char] -> [Char]
sanitizeProg = filter Base27.isLetter

-- | Execution options for setting up the 4LW virtual machine.
data ProgOptions = ProgOptions { filename :: String
                             , tickTime :: Int
                             --, tapeFiles :: [(Letter, String)]
                             , tapeFile :: Maybe String
                             } deriving (Show)

-- | Parses the command line options.
parseOptions :: Parser ProgOptions
parseOptions = ProgOptions
                   <$> strArgument (metavar "FILE")
                   <*> option auto (short 't' <> value 1000)
                   <*> optional (strOption (short 'T'))

-- | Parses the command line option and provides help info.
optionsAndInfo :: ParserInfo ProgOptions
optionsAndInfo = info (helper <*> parseOptions)
    (fullDesc <> progDesc "4LW is a virtual machine implementing a base-27 architecture.")

main :: IO ()
main = do
    options <- execParser optionsAndInfo

    -- Read in the memory file.
    prog <- readFile (filename options)

    -- Read in the tape, if any.
    tapeStr <- case tapeFile options of
            Just fname -> catch (readFile fname) (\(e :: SomeException) -> putStrLn "Error reading tape" >> return "")
            Nothing -> return ""

    -- Nasty way of forcing haskell to read in the entire file.
    -- Else the laziness breaks things when you try to write the file back out.
    seq (length tapeStr) (return ())

    -- Load the memory file into main memory.
    let statemem = memory %~ fromJust . importString (sanitizeProg prog) minWord $ blankState
    let state = tapeDeck . at (letter 'A') .~ Just (Tapes.newTape (WS.readWordsFiltered tapeStr)) $ statemem

    -- | Set up the default run options for the 4LW VM
    let runOptions = RunOptions {
      _ticktime = tickTime options,
      _commandFn = VMInterface.interface
    }

    -- Run the 4LW VM
    (_, state') <- runStateT (start runOptions) state
    -- Done running
    -- Save the tape:
    hPutStr stderr "\n\n\n"
    case tapeFile options of
      Just fname -> do
           hPutStrLn stderr $ "Saving " ++ fname
           Tapes.writeTapeToFile fname (fromJust (view (tapeDeck . at (letter 'A')) $ state'))
      Nothing -> return ()

    hPutStrLn stderr "4LW shutting down."

    hPutStrLn stderr "PC was at: "
    hPrint stderr $ fromJust $ state' ^? registers . ix pcRegister

    hPutStr stderr "Ticks: "
    hPrint stderr $ state' ^. tickNum
