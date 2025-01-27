{-# OPTIONS --prop --rewriting #-}

module Examples.Sequence.DerivedFormsRBT where

open import Examples.Sequence.RedBlackTree

open import Calf.CostMonoid
open import Calf.CostMonoids using (ℕ²-ParCostMonoid)

open ParCostMonoid parCostMonoid

open import Calf costMonoid
open import Calf.ParMetalanguage parCostMonoid

open import Calf.Types.Nat
open import Calf.Types.List
open import Calf.Types.Product
open import Calf.Types.Sum
open import Calf.Types.Bounded costMonoid
open import Data.Product hiding (map)
open import Data.List as List hiding (sum; map)
import Data.List.Properties as List
open import Data.Nat as Nat using (_+_; _*_; _<_; _>_; _≤ᵇ_; _<ᵇ_; ⌊_/2⌋; _≡ᵇ_; _≥_; _∸_)
import Data.Nat.Properties as Nat
open import Data.Nat.Logarithm

open import Level using (0ℓ)
open import Function using (_$_)
open import Relation.Nullary
open import Relation.Binary
open import Relation.Binary.PropositionalEquality as Eq using (_≡_; refl; _≢_; module ≡-Reasoning; ≢-sym)


module Sum where
  sum/seq : cmp $
    Π color λ y → Π nat λ n → Π (list nat) λ l → Π (irbt nat y n l) λ _ → F nat
  sum/seq .black .zero .[] leaf = ret 0
  sum/seq .red n .(_ ++ [ a ] ++ _) (red t₁ a t₂) =
    step (F nat) (1 , 1) $
      bind (F (nat)) ((sum/seq _ _ _ t₁) & (sum/seq _ _ _ t₂))
      (λ (s₁ , s₂) → ret (s₁ + a + s₂))
  sum/seq .black .(suc _) .(_ ++ [ a ] ++ _) (black t₁ a t₂) =
    step (F nat) (1 , 1) $
      bind (F (nat)) ((sum/seq _ _ _ t₁) & (sum/seq _ _ _ t₂))
      (λ (s₁ , s₂) → ret (s₁ + a + s₂))

  span/sum : val color → val nat → val nat
  span/sum red n = 1 + 2 * n
  span/sum black n = 2 * n

  span/bounded : ∀ y n → (span/sum y n) Nat.≤ (1 + 2 * n)
  span/bounded red n = Nat.≤-refl
  span/bounded black n = Nat.n≤1+n (2 * n)

  sum/bounded' : ∀ y n l t → IsBounded nat (sum/seq y n l t) (List.length l , span/sum y n)
  sum/bounded' .black .zero .[] leaf = bound/relax (λ x → Nat.z≤n , Nat.z≤n) bound/ret
  sum/bounded' .red n l (red {l₁ = l₁} {l₂ = l₂} t₁ a t₂) =
    Eq.subst
      (IsBounded _ _) {y = List.length l , 1 + 2 * n}
        (begin
          (1 , 1) ⊕ (length l₁ + length l₂ , n + (n + zero))
        ≡⟨⟩
          (1 + (length l₁ + length l₂) , 1 + (n + (n + zero)))
        ≡˘⟨ Eq.cong₂ _,_ (Nat.+-assoc 1 (length l₁) (length l₂)) refl ⟩
          (1 + length l₁ + length l₂ , suc (n + (n + zero)))
        ≡⟨ Eq.cong₂ _,_ (Eq.cong₂ _+_ (Nat.+-comm 1 (length l₁)) refl) refl ⟩
          (length l₁ + 1 + length l₂ , suc (n + (n + zero)))
        ≡⟨ Eq.cong₂ _,_ (Nat.+-assoc (length l₁) 1 (length l₂)) refl ⟩
          (length l₁ + (1 + length l₂) , suc (n + (n + zero)))
        ≡⟨⟩
          (length l₁ + length (a ∷ l₂) , suc (n + (n + zero)))
        ≡˘⟨ Eq.cong₂ _,_ (List.length-++ l₁) refl ⟩
          (length (l₁ ++ a ∷ l₂) , suc (n + (n + zero)))
        ∎)
      (bound/step (1 , 1) (List.length l₁ + List.length l₂  , 2 * n)
        (Eq.subst
          (IsBounded _ _) {x = List.length l₁ + List.length l₂ + 0 , 2 * n + 0}
          (Eq.cong₂ _,_ (Nat.+-identityʳ (List.length l₁ + List.length l₂)) (Nat.+-identityʳ (2 * n)))
          (bound/bind/const
            (List.length l₁ + List.length l₂  , 2 * n)
            𝟘
            (Eq.subst
              (IsBounded _ _)
              (Eq.cong₂ _,_ refl (Nat.⊔-idem (2 * n)))
              (bound/par (sum/bounded' _ _ _ t₁) (sum/bounded' _ _ _ t₂)))
            (λ _ → bound/ret)))
      )
        where open ≡-Reasoning
  sum/bounded' .black n@(suc n') l (black {y₁ = y₁} {y₂ = y₂} {l₁ = l₁} {l₂ = l₂} t₁ a t₂) =
    Eq.subst
      (IsBounded _ _) {y = List.length l , 2 * (suc n') }
        (begin
          (1 , 1) ⊕ (length l₁ + length l₂ , suc (n' + (n' + zero)))
        ≡⟨⟩
          (1 + (length l₁ + length l₂) , suc (suc (n' + (n' + zero))))
        ≡˘⟨ Eq.cong₂ _,_ (Nat.+-assoc 1 (length l₁) (length l₂)) (Eq.cong suc (Eq.cong₂ _+_ (Nat.+-comm n' 1) refl)) ⟩
          (1 + length l₁ + length l₂ , suc (n' + 1 + (n' + zero)))
        ≡⟨ Eq.cong₂ _,_ (Eq.cong₂ _+_ (Nat.+-comm 1 (length l₁)) refl) (Eq.cong suc (Nat.+-assoc n' 1 (n' + zero))) ⟩
          (length l₁ + 1 + length l₂ , suc (n' + (1 + (n' + zero))))
        ≡⟨ Eq.cong₂ _,_ (Nat.+-assoc (length l₁) 1 (length l₂)) refl ⟩
          (length l₁ + (1 + length l₂) , suc (n' + (1 + (n' + zero))))
        ≡⟨⟩
          (length l₁ + length (a ∷ l₂) , suc (n' + (1 + (n' + 0))))
        ≡˘⟨ Eq.cong₂ _,_ (List.length-++ l₁) refl ⟩
          (length (l₁ ++ a ∷ l₂) , suc (n' + suc (n' + zero)))
        ∎)
      (bound/step (1 , 1) (List.length l₁ + List.length l₂ ,  1 + 2 * n')
        (Eq.subst
          (IsBounded _ _)  {x = List.length l₁ + List.length l₂ + 0 , 1 + 2 * n' + 0}
          (Eq.cong₂ _,_ (Nat.+-identityʳ (List.length l₁ + List.length l₂)) (Nat.+-identityʳ (1 + 2 * n')))
          (bound/bind/const (List.length l₁ + List.length l₂ , 1 + 2 * n') 𝟘
            (Eq.subst
              (IsBounded _ _)
              (Eq.cong₂ _,_ refl (Nat.⊔-idem (1 + 2 * n')))
              (bound/par
                (bound/relax (λ u → Nat.≤-refl , (span/bounded y₁ n')) (sum/bounded' _ _ _ t₁))
                (bound/relax (λ u → Nat.≤-refl , (span/bounded y₂ n')) (sum/bounded' _ _ _ t₂))))
            (λ a₁ → bound/ret))))
        where open ≡-Reasoning

  sum/bounded : ∀ y n l t → IsBounded nat (sum/seq y n l t) (length l , 1 + 2 * ⌈log₂ (1 + length l) ⌉)
  sum/bounded y n l t = bound/relax (λ u → Nat.≤-refl , lemma) (sum/bounded' y n l t)
    where
      open Nat.≤-Reasoning

      lemma : span/sum y n Nat.≤ suc (2 * ⌈log₂ (1 + length l) ⌉)
      lemma =
        begin
          span/sum y n
        ≤⟨ span/bounded y n ⟩
          suc (2 * n)
        ≤⟨ Nat.s≤s (Nat.*-monoʳ-≤ 2 (i-nodes/bound/log-node-black-height t)) ⟩
          suc (2 * ⌈log₂ (1 + i-nodes t) ⌉)
        ≡⟨ Eq.cong (λ x → suc (2 * ⌈log₂ (1 + x) ⌉)) (i-nodes≡lengthl t) ⟩
          suc (2 * ⌈log₂ (1 + length l) ⌉)
        ∎


module _ (Key : StrictTotalOrder 0ℓ 0ℓ 0ℓ) where
  open StrictTotalOrder Key

  𝕂 : tp pos
  𝕂 = U (meta (StrictTotalOrder.Carrier Key))
