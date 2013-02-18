{-# LANGUAGE  FlexibleContexts, NoMonomorphismRestriction, RankNTypes #-}

-- The parser transforms the input text into an AST
module Parser where

import Text.ParserCombinators.UU
import qualified Text.ParserCombinators.UU.BasicInstances as PC
import           Text.ParserCombinators.UU.BasicInstances (Parser)
-- import Text.ParserCombinators.UU.Derived
import Text.ParserCombinators.UU.Utils hiding (runParser)
import Text.Printf (printf)
import Data.Char (ord)

import Ast

pProg :: Parser AstProg
pProg = AstProg <$> some pDecl

pDecl :: Parser AstDecl
pDecl = pVarDecl -- <|> pFunDecl

pVarDecl :: Parser AstDecl
pVarDecl = AstVarDecl <$> pType <*> pIdentifier <* pSymbol "=" <*> pExpr <* pSymbol ";"

-- pFunDecl = undefined

pType :: Parser AstType
pType = lexeme $
      BaseType <$> PC.pToken "Int"
  <|> BaseType <$> PC.pToken "Bool"
  <|> TupleType <$ pSymbol "(" <*> pType <* pSymbol "," <*> pType <* pSymbol ")"
  <|> ListType <$ pSymbol "[" <*> pType <* pSymbol "]"

pIdentifier :: Parser String
pIdentifier = lexeme $ many pLetter

pExpr :: Parser AstExpr
pExpr = AstInteger <$> lexeme pInt
    <<|> AstBoolean <$> pBool
    <<|> AstIdentifier <$> pIdentifier

pInt :: Parser Integer
pInt = opt (negate <$ pSymbol "-") id <*> pChainl (pure $ \num digit -> num * 10 + digit) ((\c -> toInteger (ord c - ord '0')) <$> pDigit)

pBool :: Parser Bool
pBool = True <$ PC.pToken "True"
    <|> False <$ PC.pToken "False"


runParser :: String -> PC.Parser a -> String -> a
runParser inputName parser input | (a,b) <- execParser parser input =
    if null b
    then a
    else error (printf "Failed parsing '%s' :\n%s\n" inputName (pruneError input b))
         -- We do 'pruneError' above because otherwise you can end
         -- up reporting huge correction streams, and that's
         -- generally not helpful... but the pruning does discard info...
    where -- | Produce a single simple, user-friendly error message
        pruneError :: String -> [PC.Error PC.LineColPos] -> String
        pruneError _ [] = ""
        pruneError _ (PC.DeletedAtEnd x     : _) = printf "Unexpected '%s' at end." x
        pruneError s (PC.Inserted _ position expr : _) = prettyError s expr position
        pruneError s (PC.Deleted  _ position expr : _) = prettyError s expr position
        pruneError _ (PC.Replaced _ _ _ _ : _) = error "pruneError: unhandled case `Replaced`" -- don't know what to do, don't care (for now)
        prettyError :: String -> [String] -> PC.LineColPos -> String
        prettyError s expr loc@(PC.LineColPos _ _ pos) = printf "Expected %s at %s :\n%s\n%s\n%s\n"
                                                           (PC.show_expecting loc expr)
                                                           (show loc)
                                                           aboveString
                                                           inputFrag
                                                           belowString
                             where
                                s' = map (\c -> if c=='\n' || c=='\r' || c=='\t' then ' ' else c) s
                                aboveString = replicate 30 ' ' ++ "v"
                                belowString = replicate 30 ' ' ++ "^"
                                inputFrag   = replicate (30 - pos) ' ' ++ (take 71 $ drop (pos - 30) s')