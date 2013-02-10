{-# LANGUAGE  FlexibleContexts #-}

module UUParsinglib where

import Text.ParserCombinators.UU
import Text.ParserCombinators.UU.BasicInstances

pa = pSym 'a'
parseA = run pa "aabb"

parens :: Parser Int
parens =
  (\_ p _ q -> max (p+1) q)
    <$> (pSym '(') <*> parens <*> pSym ')' <*> parens
  <|> pure 0
-- parseParens = run parens "###(())(a)"
parseParens = run parens "#"

run p input = parse ((,) <$> p <*> pEnd) (createStr (LineCol 0 0) input)

main = do
  let (a, errors) = parseParens
  putStrLn ("-- Result: " ++ show a)
  if null errors
    then return ()
    else do putStrLn ("-- Errors: ")
            (sequence_ . (map (putStrLn . show))) errors
