module BackendSsm where

import Control.Monad.Trans.State

import IntermediateRepresentation

ssmMachine = mkMachine (-1) 0 4 makePrologue makeEpilogue

makePrologue :: Machine -> IR IrStatement
makePrologue m = do
  name <- gets machineCurFunctionName
  return $ IrAsm [name ++ ": ldr MP", "ldrr MP SP"]

makeEpilogue :: Machine -> IR IrStatement
makeEpilogue m = return $ IrAsm ["str MP", "ret"]

generateE :: IrExpression -> Asm -> Asm
generateE (IrBinOp op lhs rhs) c = genrerateBinOp op $ generateE rhs $ generateE lhs c
generateE (IrConst i) c = c ++ ["ldc " ++ show i]
generateE (IrCall name args) c = c ++ ["ldc 0"] ++ concat (map (\a -> generateE a []) args) ++ ["bsr " ++ name, "ajs -" ++ show (length args)]

generateS :: IrStatement -> Asm -> Asm
generateS (IrAsm asm) c = c ++ asm
generateS (IrJump name) c = c ++ ["bra " ++ name]
generateS (IrLabel name) c = c ++ [name ++ ":"]
generateS (IrSeq s1 s2) c = generateS s2 (generateS s1 c)
generateS (IrExp e) c = generateE e c ++ ["ajs -1"] -- TODO: don't pop value for calls to Void functions
generateS (IrMove (IrMem (IrBinOp OpAdd (IrTemp IrFramePointer) (IrConst n))) val) c = generateE val c ++ ["stl " ++ show n]

generateSs :: [IrStatement] -> Asm
generateSs stmts = generateE (IrCall "main" []) [] ++ ["halt"] ++ (concat $ map (\s -> generateS s []) stmts)

genrerateBinOp :: IrBinOp -> Asm -> Asm
genrerateBinOp OpAdd c = c ++ ["add"]
genrerateBinOp OpSub c = c ++ ["sub"]
genrerateBinOp OpMul c = c ++ ["mul"]
genrerateBinOp OpDiv c = c ++ ["div"]
genrerateBinOp OpMod c = c ++ ["mod"]

genrerateBinOp OpEq  c = c ++ ["eq"]
genrerateBinOp OpNeq c = c ++ ["ne"]
genrerateBinOp OpLt  c = c ++ ["lt"]
genrerateBinOp OpLte c = c ++ ["le"]
genrerateBinOp OpGt  c = c ++ ["gt"]
genrerateBinOp OpGte c = c ++ ["ge"]

genrerateBinOp OpAnd c = c ++ ["and"]
genrerateBinOp OpOr  c = c ++ ["or"]