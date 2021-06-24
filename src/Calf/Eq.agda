{-# OPTIONS --prop --without-K --rewriting #-}

open import Calf.CostMonoid

module Calf.Eq (CostMonoid : CostMonoid) where

open import Calf.Prelude
open import Calf.Metalanguage CostMonoid
open import Calf.PhaseDistinction CostMonoid

postulate
  eq : (A : tp pos) → val A → val A → tp pos
  eq/intro : ∀ {A v1 v2} → v1 ≡ v2 → val (eq A v1 v2)
  eq/ref : ∀ {A v1 v2} → cmp (F (eq A v1 v2)) → v1 ≡ v2