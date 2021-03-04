{-# OPTIONS --prop --rewriting #-}

-- This file adds the phase distinction for extension.

module PhaseDistinction where

open import Prelude
open import Metalanguage
open import CostEffect

postulate
  ext : Ω

◯ : □ → □
◯ A = ext → A

postulate
  step/ext : ∀ X → (e : cmp X) → ◯ (step X e ≡ e)
  -- sadly the above cannot be made an Agda rewrite rule


-- Underneath the open modality, we ensure that the abstract types
-- that force you to take steps don't do anything.

postulate
  ►/ext : ∀ A → ◯ (val (► A) → val A)
  ►/ext/β : ∀ {A} {z : ext} {u : val A} → ►/ext A z (►/ret A u) ≡ u
  {-# REWRITE ►/ext/β #-}

  ►/ext/η : ∀ {A} (z : ext) (u : val (► A)) → ►/ret A (►/ext A z u) ≡ u

►/ext/match : ∀ {A X} {u : val (► A)} {f : val A → cmp X} {z : ext} → ►/match X u f ≡ f (►/ext A z u)
►/ext/match {A} {X} {u} {f} {z} rewrite (symm (►/ext/η z u)) = step/ext X (f (►/ext A z u)) z

postulate
  ▷/ext : ∀ X → ◯ (cmp (▷ X) → cmp X)
  ▷/ext/β : ∀ {X} {z : ext} {u : cmp X} → ▷/ext X z (▷/ret X u) ≡ u
  {-# REWRITE ▷/ext/β #-}

  ▷/ext/η : ∀ {X} (z : ext) (u : cmp (▷ X)) → ▷/ret X (▷/ext X z u) ≡ u

▷/ext/match : ∀ {Y X} {u : cmp (▷ Y)} {f : cmp Y → cmp X} {z : ext} → ▷/match X u f ≡ f (▷/ext Y z u)
▷/ext/match {Y} {X} {u} {f} {z} rewrite (symm (▷/ext/η z u)) = step/ext X (f (▷/ext Y z u)) z

►/ind : ∀ {A} {P : val (► A) → □} → ◯ ((∀ x → P (►/ret _ x)) → ∀ x → P x)
►/ind {A} z f x rewrite (symm (►/ext/η z x)) = f (►/ext A z x)