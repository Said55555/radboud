module assignment08klinik

import StdEnv
import gast

/* === Deliverable 1: model of the vending machine === */

:: Input
  = C Coin
  | D Digit // one of the digits on the screen
  | ButtonReset // cancel selection of product
  | ButtonOk // purchase selected product
  | ButtonReturn  // cancel purchase and return all money

:: Output
  = Change [Coin]
  | Product Product Int // for testing, we include how much the product costs

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

unCoin (Coin c) = c

vendingMachineModel :: ModelState Input -> [Trans Output ModelState]
vendingMachineModel s (C (Coin coin)) = [insertCoin]
  where
    insertCoin =
      if (s.ModelState.balance + coin < s.ModelState.balance)
         // don't accept new coins if it would lead to overflow
         (Pt [Change [(Coin coin)]] s) // immediately return the original coin
         (Pt [] { ModelState | s & balance = s.ModelState.balance + coin })
vendingMachineModel s ButtonReturn = [Ft (checkChange s)]
vendingMachineModel s (D digit) = [Pt [] { ModelState | s & digitsEntered = enterDigit digit s.ModelState.digitsEntered }]
vendingMachineModel s ButtonReset = [Pt [] { ModelState | s & digitsEntered = (Nothing, Nothing) }]
vendingMachineModel s ButtonOk = [ Pt [] s // we allow the identity transition in case the item is out of stock
                                 : makePurchaseModel s
                                 ]

checkChange :: ModelState [Output] -> [ModelState]
checkChange s [(Change coins)]
  | (sumCoins coins) == s.ModelState.balance = [{ ModelState | s & balance = 0 }]
  = []
checkChange _ _ = []

sumCoins :: [Coin] -> Int
sumCoins coins = foldl (\sum (Coin c) -> sum + c) 0 coins

makePurchaseModel :: ModelState -> [Trans Output ModelState]
makePurchaseModel s =
  case s.ModelState.digitsEntered of
    // if the user has actually entered two digits ...
    (Just d1, Just d2) = case lookupProduct (d1, d2) s.ModelState.stock of
      // ... and these digits correspond to a product in stock ...
      (Just stockProduct) = if (s.ModelState.balance >= stockProduct.price)
        // ... and the user has inserted enough money
        [Pt [Product stockProduct.product stockProduct.price] // then: return the product,
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

/* === Deliverable 2: implementation of the vending machine === */

// In my implementation, it is possible to make multiple purchases when the
// balance is sufficient.  To get the change back, the user has to explicitly
// press the Return button.  That is because I hate vending machines that
// return your change after each purchase.

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
derive ggen Input, ModelState, StockProduct, Maybe, Product
derive bimap []

coinSizes = [5, 10, 20, 50, 100, 200]

/* Only two buttons for digits: 0 and 1. This gives a higher probability for
 * successful purchases to occur in tests.
 */
ggen{|Digit|} n r = randomize (map Digit [0..1]) r 10 (const [])
ggen{|Coin|} n r = randomize (map Coin coinSizes) r 10 (const [])

vendingMachine :: MachineState Input -> ([Output], MachineState)
vendingMachine s (C (Coin coin)) = ([], { MachineState | s & balance = s.MachineState.balance + coin })
vendingMachine s ButtonReturn    = ([Change (makeChange s.MachineState.balance)], { MachineState | s & balance = 0 })
vendingMachine s (D digit)       = ([], { MachineState | s & digitsEntered = enterDigit digit s.MachineState.digitsEntered })
vendingMachine s ButtonReset     = ([], { MachineState | s & digitsEntered = (Nothing, Nothing) })
vendingMachine s ButtonOk        = makePurchase s

// makeChange returns all the change as one big fat custom coin of exactly that
// amount, because tracking the machine's coins and giving exact change is
// tedious and not very enlightening.  The case where the machine doesn't spit
// out a product because of insufficient change is already covered by the one
// non-deterministic case of the model, so this wouldn't even be interesting
// from a testing standpoint.
makeChange :: Int -> [Coin]
makeChange amount = [Coin amount]

makePurchase :: MachineState -> ([Output], MachineState)
makePurchase s =
  case s.MachineState.digitsEntered of
    // if the user has actually entered two digits ...
    (Just d1, Just d2) = case lookupProduct (d1, d2) s.MachineState.stock of
      // ... and these digits correspond to a product in stock ...
      (Just stockProduct) = if (s.MachineState.balance >= stockProduct.price && stockProduct.quantity > 0)
        // ... and the user has inserted enough money, and there is at least one such product in stock
        ([Product stockProduct.product stockProduct.price] // then: return the product,
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

implStartState =
  { MachineState
  | balance = 0
  , digitsEntered = (Nothing, Nothing)
  , stock = theStock
  }

// Initially, we only have one item of each kind in stock.
// When we pre-load more items of each kind, the case that a product is out of
// stock never happens.
// Remember: only Digits 0 or 1 are allowed
theStock =
  [ { product = CaffeinatedBeverage
    , id = (Digit 0, Digit 1)
    , price = 85
    , quantity = 1
    }
  , { product = EnergyBar
    , id = (Digit 1, Digit 0)
    , price = 120
    , quantity = 0 // out of stock by default
    }
  , { product = Apple
    , id = (Digit 1, Digit 1)
    , price = 5
    , quantity = 1
    }
  ]


/* === Properties for testing the model with Gast === */


/* Transitions preserve validity of model states */
validity :: ModelState Input -> Property
validity state input = validModelState state ==> and (map checkTransition (vendingMachineModel state input))
where
  checkTransition (Pt _ newState) = validModelState newState
  checkTransition (Ft f) = True // I don't know what to do in this case


/* Determines if a model state is valid, that is:
 *  - balance is >= 0
 *  - prices of all products are > 0
 *  - quantities of products are >= 0
 *  - entered digits are either
 *      (Nothing, Nothing)
 *      (Digit  , Nothing)
 *      (Digit  , Digit  )
 *    but not
 *      (Nothing, Digit  )
 */
validModelState :: ModelState -> Bool
validModelState state =
  and [ state.ModelState.balance >= 0
      , and [ product.price > 0 \\ product <- state.ModelState.stock ]
      , and [ product.quantity >= 0 \\ product <- state.ModelState.stock ]
      , validDigits state.ModelState.digitsEntered
      ]
where
  validDigits (Nothing, Just _) = False
  validDigits _ = True


/* The specification is fair iff for all possible transitions,
 *   value of source state + input = value of destination state + output
 */
fairness :: ModelState Input -> Property
fairness state input = validModelState state ==> and (map checkTransition (vendingMachineModel state input))
where
  checkTransition (Pt outputs newState) = oldTotal == newTotal
    where
      oldTotal = state.ModelState.balance + valueOfInput input
      newTotal = newState.ModelState.balance + sum (map valueOfOutput outputs)
  checkTransition (Ft f) = True

  valueOfOutput (Change coins) = sum (map unCoin coins)
  // A product's price is part of the output for exactly this line.  It avoids
  // having to search the stock for this product.
  valueOfOutput (Product _ price) = price

  valueOfInput (C (Coin coin)) = coin
  valueOfInput _ = 0 // only coin inputs have monetary values


/* The model sells (i.e. has as outputs) only products which are actually in
 * stock
 */
onlyStockProducts :: ModelState Input -> Property
onlyStockProducts state input = validModelState state ==> and (map checkTransition (vendingMachineModel state input))
where
  checkTransition (Pt outputs _) = productsAreInStock outputs
  checkTransition (Ft f) = True
  productsAreInStock [(Product p _):rest] = productIsInStock p state.ModelState.stock && (productsAreInStock rest)
  productsAreInStock [_:rest] = productsAreInStock rest
  productsAreInStock [] = True

  productIsInStock product [stock:stocks] = product === stock.product || productIsInStock product stocks
  productIsInStock _ [] = False


/* The Reset button only resets the digits, and leaves the balance untouched */
resetButton :: ModelState -> Property
resetButton state = validModelState state ==> and (map checkTransition (vendingMachineModel state ButtonReset))
where
  checkTransition (Pt _ newState) =
          state.ModelState.balance == newState.ModelState.balance
      &&  newState.ModelState.digitsEntered === (Nothing, Nothing)
  checkTransition (Ft f) = True


Start world =
  //testSM world
  test validity ++
  test fairness ++
  test onlyStockProducts ++
  test resetButton

/* === testing of the vending machine implementation against the model === */

testSM world =
  testConfSM
    [/*Ntests 1000, */ MkTrace True] // test options
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
