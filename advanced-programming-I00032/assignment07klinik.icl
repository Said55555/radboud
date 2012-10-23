module assignment07klinik

import StdEnv
import gast

/* === Model of the vending machine === */

:: Input
  = C Coin
  | D Digit // one of the digits on the screen
  | ButtonReset // cancel selection of product
  | ButtonOk // purchase selected product
  | ButtonReturn  // cancel purchase and return all money

:: Output = Change Coin | Product Product

:: ModelState =
  { balance :: Int
  , digitsEntered :: (Maybe Digit, Maybe Digit)
  , stock :: [StockProduct]
  }

:: StockProduct =
  { product :: Product // this product
  , id :: (Digit, Digit) // which digits it's assigned to
  , price :: Int // how much it costs
  , quantity :: Int // how much items are in stock
  }


:: Product = CaffeinatedBeverage | EnergyBar | Apple

:: Coin = Coin Int
:: Digit = Digit Int

vendingMachineModel :: ModelState Input -> [Trans Output ModelState]
vendingMachineModel s (C (Coin coin)) = [Pt [] { ModelState | s & balance = s.ModelState.balance + coin }]
vendingMachineModel s ButtonReturn = [Pt [Change (Coin s.ModelState.balance)] { ModelState | s & balance = 0 }]
vendingMachineModel s (D digit) = [Pt [] { ModelState | s & digitsEntered = enterDigit digit s.ModelState.digitsEntered }]
vendingMachineModel s ButtonReset = [Pt [] { ModelState | s & digitsEntered = (Nothing, Nothing) }]
vendingMachineModel s ButtonOk = [ Pt [] s // we allow the identity transition in case the item is out of stock
                                 : makePurchaseModel s
                                 ]

makePurchaseModel :: ModelState -> [Trans Output ModelState]
makePurchaseModel s =
  case s.ModelState.digitsEntered of
    // if the user has actually entered two digits ...
    (Just d1, Just d2) = case lookupProduct (d1, d2) s.ModelState.stock of
      // ... and these digits correspond to a product in stock ...
      (Just stockProduct) = if (s.ModelState.balance >= stockProduct.price)
        // ... and the user has inserted enough money
        [Pt [Product stockProduct.product] // then: return the product,
          { ModelState | s
          & balance = s.ModelState.balance - stockProduct.price // reduce the balance,
          , digitsEntered = (Nothing, Nothing) // and clear the entered digits
          }
        ]
        meh
      = meh
    = meh
where
  meh = [Pt [] s]

:: MachineState =
  { balance :: Int
  , digitsEntered :: (Maybe Digit, Maybe Digit)
  , stock :: [StockProduct]
  }

enterDigit :: Digit (Maybe Digit, Maybe Digit) -> (Maybe Digit, Maybe Digit)
enterDigit d (Nothing, Nothing) = (Just d, Nothing) // enter the first digit
enterDigit d (Just d1, Nothing) = (Just d1, Just d) // enter the second digit
enterDigit _ x = x // cannot enter more than two digits

derive genShow MachineState, ModelState, Input, Output, Digit, Coin, Product, StockProduct, Maybe
derive gEq ModelState, Output, Product, Coin, StockProduct, Digit, Maybe
derive ggen Input
derive bimap []

ggen{|Digit|} n r = randomize (map Digit [0..9]) r 10 (const [])
ggen{|Coin|} n r = randomize (map Coin [5, 10, 20, 50, 100, 200]) r 10 (const [])

vendingMachine :: MachineState Input -> ([Output], MachineState)
vendingMachine s (C (Coin coin)) = ([], { MachineState | s & balance = s.MachineState.balance + coin })
vendingMachine s ButtonReturn    = ([Change (Coin s.MachineState.balance)], { MachineState | s & balance = 0 })
vendingMachine s (D digit)       = ([], { MachineState | s & digitsEntered = enterDigit digit s.MachineState.digitsEntered })
vendingMachine s ButtonReset     = ([], { MachineState | s & digitsEntered = (Nothing, Nothing) })
vendingMachine s ButtonOk        = makePurchase s

makePurchase :: MachineState -> ([Output], MachineState)
makePurchase s =
  case s.MachineState.digitsEntered of
    // if the user has actually entered two digits ...
    (Just d1, Just d2) = case lookupProduct (d1, d2) s.MachineState.stock of
      // ... and these digits correspond to a product in stock ...
      (Just stockProduct) = if (s.MachineState.balance >= stockProduct.price && stockProduct.quantity > 0)
        // ... and the user has inserted enough money, and there is at least one such product in stock
        ([Product stockProduct.product] // then: return the product,
        , { MachineState | s
          & balance = s.MachineState.balance - stockProduct.price // reduce the balance,
          , digitsEntered = (Nothing, Nothing) // clear the entered digits,
            // and reduce the quantity of this item by one
          , stock = updateStock (d1, d2) (\p -> { p & quantity = p.quantity - 1}) s.MachineState.stock
          }
        )
        meh
      = meh
    = meh
where
  meh = ([], s)

lookupProduct :: (Digit, Digit) [StockProduct] -> Maybe StockProduct
lookupProduct _ [] = Nothing
lookupProduct id [p:ps] = if (p.id === id) (Just p) (lookupProduct id ps)

updateStock :: (Digit, Digit) (StockProduct -> StockProduct) [StockProduct] -> [StockProduct]
updateStock _ _ [] = []
updateStock id f [p:ps] = if (p.id === id) [f p : ps] [p : updateStock id f ps]

(step) infixl :: ([Output], MachineState) Input -> ([Output], MachineState)
(step) (_, s) i = vendingMachine s i

Start2 = vendingMachine implStartState (D (Digit 4)) step (D (Digit 2)) step (C (Coin 5)) step ButtonOk

implStartState =
  { MachineState
  | balance = 0
  , digitsEntered = (Nothing, Nothing)
  , stock = theStock
  }

theStock =
  [ { product = CaffeinatedBeverage
    , id = (Digit 0, Digit 0)
    , price = 85
    , quantity = 1
    }
  , { product = EnergyBar
    , id = (Digit 1, Digit 8)
    , price = 120
    , quantity = 1
    }
  , { product = Apple
    , id = (Digit 4, Digit 2)
    , price = 5
    , quantity = 1
    }
  ]

Start world =
  testConfSM
    [/*Ntests 10*/] // test options
    vendingMachineModel // specification
    { ModelState // spec start state
    | stock = theStock
    , balance = 0
    , digitsEntered = (Nothing, Nothing)
    }
    vendingMachine // implementation
    implStartState // implementation start state
    (const implStartState) // reset function
    world
