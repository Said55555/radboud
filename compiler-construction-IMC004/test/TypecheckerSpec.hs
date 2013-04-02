{-# LANGUAGE  FlexibleContexts, NoMonomorphismRestriction, RankNTypes #-}

module TypecheckerSpec (spec, main) where

import Test.Hspec
import Control.Monad.Trans.Either
import Control.Monad.Trans.State.Lazy

import Parser
import Utils
import Typechecker
import SplType
import Ast

main :: IO ()
main = hspec spec

-- evaluate a typecheck action in an empty environment
evalTypecheckBare :: (Typecheck a) -> a
evalTypecheckBare t = unRight $ evalState (runEitherT (t)) (0, emptyEnvironment)

parseConvertShow :: String -> String
parseConvertShow s = convertShow $ parse pReturnType s

convertShow :: AstType -> String
convertShow t = show $ evalTypecheckBare $ astType2splType t

typeInt, typeBool, typeVoid :: AstType
typeInt = BaseType emptyMeta "Int"
typeBool = BaseType emptyMeta "Bool"
typeVoid = BaseType emptyMeta "Void"
typeVar :: String -> AstType
typeVar x = PolymorphicType emptyMeta x

-- Given a program and an identifier, infer the type of the identifier in the
-- standard environment.
typeOf :: String -> String -> String
typeOf program identifier =
  let ast = parse pProgram program
      (Right (typ, _), _) = runTypecheck $ typecheck ast >> envLookup identifier emptyMeta
  in
    prettyprintType $ makeNiceAutoTypeVariables typ

spec :: Spec
spec = do
  describe "typeVars" $ do
    it "gives the empty list for a base type" $ null $ typeVars (SplBaseType BaseTypeInt)

  describe "astType2splType" $ do
    it "is the identity function on monomorphic types" $ do
      parseConvertShow "Bool" `shouldBe` "Bool"
      parseConvertShow "Int" `shouldBe` "Int"
      parseConvertShow "Void" `shouldBe` "Void"
    it "replaces single type variables with fresh ones" $ do
      parseConvertShow "a" `shouldBe` "<0>"
      parseConvertShow "[a]" `shouldBe` "[<0>]"
    it "replaces distinct type variables with distinct fresh ones" $ do
      parseConvertShow "(a, b)" `shouldBe` "(<0>, <1>)"
    it "replaces the same type variables with the same fresh ones" $ do
      parseConvertShow "(a, a)" `shouldBe` "(<0>, <0>)"
    it "replaces same with same and distinct with distinct type variables" $ do
      parseConvertShow "(a, (b, (b, a)))" `shouldBe` "(<0>, (<1>, (<1>, <0>)))"
    it "is the identity on monomorphic function types" $ do
      convertShow (FunctionType [typeInt, typeBool] typeVoid) `shouldBe` "(Int Bool -> Void)"
    it "replaces distinct with distinct type variables in function types" $ do
      convertShow (FunctionType [typeVar "x", typeVar "y"] (typeVar "z")) `shouldBe` "(<0> <1> -> <2>)"
    it "replaces distinct with distinct and same with same type vars in function types" $ do
      convertShow (FunctionType [typeVar "x", typeVar "y", typeVar "y"] (typeVar "x")) `shouldBe` "(<0> <1> <1> -> <0>)"

  describe "typecheck" $ do
    it "identity function" $ do
      typeOf "a id(b x){ return x; }" "id" `shouldBe` "(a -> a)"
    it "constant function" $ do
      typeOf "a const(b x, c y){ return x; }" "const" `shouldBe` "(b a -> b)"
    it "recursive list definition" $ do
      typeOf "a x = True:x;" "x" `shouldBe` "[Bool]"
