{-# LANGUAGE  FlexibleContexts, NoMonomorphismRestriction, RankNTypes #-}

module InterpreterSpec (spec, main) where

import Test.Hspec
import Test.QuickCheck
import qualified Control.Monad.Trans.State.Lazy as MT
import qualified Control.Monad.Trans.Either as MT

import Parser
import Utils
import Interpreter

unRight :: Either Value Value -> Value
unRight (Right v) = v
unRight _ = undefined

expr :: String -> Value
expr prog = unRight $ MT.evalState (MT.runEitherT (eval $ runParser_ "" pExpr prog)) emptyEnvironment

run :: String -> Value
run prog = unRight $ MT.evalState (MT.runEitherT $ interpretProgram $ runParser_ "" pProgram prog) emptyEnvironment

run_ :: [String] -> Value
run_ prog = unRight $ MT.evalState (MT.runEitherT $ interpretProgram $ runParser_ "" pProgram $ unlines prog) emptyEnvironment

testBinOp opSyntax opFunction resultConstructor =
  property $ \i1 i2 -> expr (show i1 ++ " " ++ opSyntax ++ " " ++ show i2) == (resultConstructor (opFunction i1 i2))

spec :: Spec
spec = do

  describe "Interpreter" $ do
    it "integer constant" $ run "Int main() { return 10; }" `shouldBe` (I 10)
    it "global variable" $
      run_ ["Int foo = 42;"
           ,"Int main()"
           ,"{"
           ,"  return foo;"
           ,"}"
           ] `shouldBe` (I 42)
    it "assignments" $
      run_ ["Int main()"
           ,"{"
           ,"  Int i = 5;"
           ,"  i = 10;"
           ,"  return i;"
           ,"}"
           ] `shouldBe` (I 10)
    it "side effects" $
      run_ ["Int foo = 42;"
           ,"Void bar()"
           ,"{"
           ,"  foo = 100; return;"
           ,"}"
           ,"Int main()"
           ,"{ bar();"
           ,"  return foo;"
           ,"}"
           ] `shouldBe` (I 100)
    it "environments shrink again" $ do
      run_ ["Int x = 1;"
           ,"Void bar() { Int x = 10; return; }"
           ,"Int main() { bar(); return x; }"
           ] `shouldBe` (I 1)

    it "two return statements return the first value" $ do
      run "Int main() { return 10; return 20; }" `shouldBe` (I 10)

  describe "while loop" $ do

    it "doesn't run the statement when the condition is false" $ do
      run "Int main() { Int counter = 0; while(False) { counter = counter + 1; } return counter; }"
        `shouldBe` (I 0)
    it "runs the statement once when the condition becomes false in the first iteration" $ do
      run_ ["Int main() {"
           ,"  Int counter = 0;"
           ,"  while( counter <= 0 ) counter = counter + 1;"
           ,"  return counter;"
           ,"}"
           ] `shouldBe` (I 1)
    it "runs the statement several times" $ do
      run_ ["Int main() {"
           ,"  Int counter = 0;"
           ,"  while( counter <= 10 ) counter = counter + 1;"
           ,"  return counter;"
           ,"}"
           ] `shouldBe` (I 11)

  describe "if-then-else" $ do
    it "interprets the then-branch when the condition is true" $ do
      run "Int main() { if(True) return 1000; else return 42; }"
        `shouldBe` (I 1000)
    it "interprets the else-branch when the condition is false" $ do
      run "Int main() { if(False) return 1000; else return 42; }"
        `shouldBe` (I 42)

  describe "eval" $ do
    it "evaluates integer constants" $ do
      property $ \x -> expr (show x) == (I x)
    it "evaluates integer constants" $ do
      expr "10" `shouldBe` (I 10)
      expr "-42" `shouldBe` (I (-42))

    it "evaluates boolean constants" $ do
      property $ \x -> expr (show x) == (B x)

    it "evaluates (+)" $ testBinOp "+" (+) I
    it "evaluates (-)" $ testBinOp "-" (-) I
    it "evaluates (*)" $ testBinOp "*" (*) I
    it "evaluates (/)" $ property $ \i1 i2 -> i2 /= 0 ==> expr (show i1 ++ " / " ++ show i2) == (I (div i1 i2))
    it "evaluates (%)" $ property $ \i1 i2 -> i2 /= 0 ==> expr (show i1 ++ " % " ++ show i2) == (I (mod i1 i2))
    it "evaluates (<)" $ testBinOp "<" ((<)::(Integer -> Integer -> Bool)) B
    it "evaluates (>)" $ testBinOp ">" ((>)::(Integer -> Integer -> Bool)) B
    it "evaluates (<=)" $ testBinOp "<=" ((<=)::(Integer -> Integer -> Bool)) B
    it "evaluates (>=)" $ testBinOp ">=" ((>=)::(Integer -> Integer -> Bool)) B

    it "evaluates binary boolean OR " $ testBinOp "||" (||) B
    it "evaluates binary boolean AND" $ testBinOp "&&" (&&) B

    it "evaluates unary minus" $ property $ \i -> expr ("- (" ++ show i ++ ")") == (I (-i))
    it "evaluates double negation" $ property $ \i -> expr ("--" ++ show i) == (I i)
    it "evaluates unary negation" $ property $ \i -> expr ("!" ++ show i) == (B (not i))

    it "evaluates tuples" $ do
      expr "(10, 20)" `shouldBe` T (I 10, I 20)
      expr "(10, True)" `shouldBe` T (I 10, B True)
      expr "(10, (True, False))" `shouldBe` T (I 10, T (B True, B False))


  describe "State" $ do
    it "retrieves the most recently added identifier in a singleton state" $ do
      envLookup "x" (("x" `envAdd` I 10) emptyEnvironment) `shouldBe` I 10
    it "retrieves the most recently added identifier in a state with more elements" $ do
      envLookup "y" ((("x" `envAdd` I 10) . ("y" `envAdd` B True)) emptyEnvironment) `shouldBe` B True
    it "retrieves an identifier somewhere inside the state" $ do
      envLookup "x" ((("x" `envAdd` I 10) . ("y" `envAdd` B True)) emptyEnvironment) `shouldBe` I 10

main :: IO ()
main = hspec spec
