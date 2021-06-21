{-# OPTIONS --prop --rewriting #-}

open import Calf.CostMonoid

module Calf (costMonoid : CostMonoid) where

open import Calf.Prelude hiding (_≡_; refl) public
open import Calf.Metalanguage costMonoid public
open import Calf.CostEffect costMonoid public
open import Calf.PhaseDistinction costMonoid public
open import Calf.Eq costMonoid public
open import Calf.Upper costMonoid public
open import Calf.Connectives costMonoid public

open import Calf.Refinement costMonoid public
