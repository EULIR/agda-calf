{-# OPTIONS --prop --rewriting #-}

module Examples.Exp2 where

open import Calf.CostMonoid
open import Calf.CostMonoids using (ℕ²-ParCostMonoid)

parCostMonoid = ℕ²-ParCostMonoid
open ParCostMonoid parCostMonoid

open import Calf costMonoid
open import Calf.ParMetalanguage parCostMonoid
open import Calf.Types.Bool

open import Relation.Binary.PropositionalEquality as Eq using (_≡_; refl; _≢_; module ≡-Reasoning)
open import Data.Nat as Nat
open import Data.Nat.Properties as N using (module ≤-Reasoning)
open import Data.Product
open import Data.Empty

Correct : cmp (Π (U (meta ℕ)) λ _ → F (U (meta ℕ))) → Set
Correct exp₂ = (n : ℕ) → ◯ (exp₂ n ≡ ret (2 ^ n))

lemma/2^suc : ∀ n → 2 ^ n + 2 ^ n ≡ 2 ^ suc n
lemma/2^suc n =
  begin
    2 ^ n + 2 ^ n
  ≡˘⟨ Eq.cong ((2 ^ n) +_) (N.*-identityˡ (2 ^ n)) ⟩
    2 ^ n + (2 ^ n + 0)
  ≡⟨⟩
    2 ^ n + (2 ^ n + 0 * (2 ^ n))
  ≡⟨⟩
    2 * (2 ^ n)
  ≡⟨⟩
    2 ^ suc n
  ∎
    where open ≡-Reasoning

module Slow where
  exp₂ : cmp (Π (U (meta ℕ)) λ _ → F (U (meta ℕ)))
  exp₂ zero = ret (suc zero)
  exp₂ (suc n) =
    bind (F (U (meta ℕ))) (exp₂ n & exp₂ n) λ (r₁ , r₂) →
      step (F (U (meta ℕ))) (1 , 1) (ret (r₁ + r₂))

  exp₂/correct : Correct exp₂
  exp₂/correct zero    u = refl
  exp₂/correct (suc n) u =
    begin
      exp₂ (suc n)
    ≡⟨⟩
      (bind (F (U (meta ℕ))) (exp₂ n & exp₂ n) λ (r₁ , r₂) →
        step (F (U (meta ℕ))) (1 , 1) (ret (r₁ + r₂)))
    ≡⟨ Eq.cong (bind (F (U (meta ℕ))) (exp₂ n & exp₂ n)) (funext (λ (r₁ , r₂) → step/ext (F (U (meta ℕ))) _ (1 , 1) u)) ⟩
      (bind (F (U (meta ℕ))) (exp₂ n & exp₂ n) λ (r₁ , r₂) →
        ret (r₁ + r₂))
    ≡⟨ Eq.cong (λ e → bind (F (U (meta ℕ))) (e & e) _) (exp₂/correct n u) ⟩
      step (F (U (meta ℕ))) (𝟘 ⊗ 𝟘) (ret (2 ^ n + 2 ^ n))
    ≡⟨⟩
      ret (2 ^ n + 2 ^ n)
    ≡⟨ Eq.cong ret (lemma/2^suc n) ⟩
      ret (2 ^ suc n)
    ∎
      where open ≡-Reasoning

  exp₂/cost : cmp (Π (U (meta ℕ)) λ _ → cost)
  exp₂/cost zero    = 𝟘
  exp₂/cost (suc n) = exp₂/cost n ⊗ exp₂/cost n ⊕ ((1 , 1) ⊕ 𝟘)

  exp₂/cost/closed : cmp (Π (U (meta ℕ)) λ _ → cost)
  exp₂/cost/closed n = pred (2 ^ n) , n

  exp₂/cost≡exp₂/cost/closed : ∀ n → exp₂/cost n ≡ exp₂/cost/closed n
  exp₂/cost≡exp₂/cost/closed zero    = refl
  exp₂/cost≡exp₂/cost/closed (suc n) =
    begin
      exp₂/cost (suc n)
    ≡⟨⟩
      exp₂/cost n ⊗ exp₂/cost n ⊕ ((1 , 1) ⊕ 𝟘)
    ≡⟨ Eq.cong (λ c → c ⊗ c ⊕ ((1 , 1) ⊕ 𝟘)) (exp₂/cost≡exp₂/cost/closed n) ⟩
      exp₂/cost/closed n ⊗ exp₂/cost/closed n ⊕ ((1 , 1) ⊕ 𝟘)
    ≡⟨ Eq.cong (λ m → exp₂/cost/closed n ⊗ exp₂/cost/closed n ⊕ m) (⊕-identityʳ _) ⟩
      exp₂/cost/closed n ⊗ exp₂/cost/closed n ⊕ (1 , 1)
    ≡⟨
      Eq.cong₂ _,_
        (begin
          proj₁ (exp₂/cost/closed n ⊗ exp₂/cost/closed n ⊕ (1 , 1))
        ≡⟨⟩
          proj₁ (exp₂/cost/closed n) + proj₁ (exp₂/cost/closed n) + 1
        ≡⟨ N.+-comm _ 1 ⟩
          suc (proj₁ (exp₂/cost/closed n) + proj₁ (exp₂/cost/closed n))
        ≡⟨⟩
          suc (pred (2 ^ n) + pred (2 ^ n))
        ≡˘⟨ N.+-suc (pred (2 ^ n)) (pred (2 ^ n)) ⟩
          pred (2 ^ n) + suc (pred (2 ^ n))
        ≡⟨ Eq.cong (pred (2 ^ n) +_) (N.suc[pred[n]]≡n (lemma/2^n≢0 n)) ⟩
          pred (2 ^ n) + 2 ^ n
        ≡⟨ lemma/pred-+ (2 ^ n) (2 ^ n) (lemma/2^n≢0 n) ⟩
          pred (2 ^ n + 2 ^ n)
        ≡⟨ Eq.cong pred (lemma/2^suc n) ⟩
          pred (2 ^ suc n)
        ≡⟨⟩
          proj₁ (exp₂/cost/closed (suc n))
        ∎)
        (begin
          proj₂ (exp₂/cost/closed n ⊗ exp₂/cost/closed n ⊕ (1 , 1))
        ≡⟨⟩
          proj₂ (exp₂/cost/closed n) ⊔ proj₂ (exp₂/cost/closed n) + 1
        ≡⟨⟩
          n ⊔ n + 1
        ≡⟨ Eq.cong (_+ 1) (N.⊔-idem n) ⟩
          n + 1
        ≡⟨ N.+-comm _ 1 ⟩
          suc n
        ≡⟨⟩
          proj₂ (exp₂/cost/closed (suc n))
        ∎)
      ⟩
        exp₂/cost/closed (suc n)
      ∎
      where
        open ≡-Reasoning

        lemma/2^n≢0 : ∀ n → 2 ^ n ≢ zero
        lemma/2^n≢0 n 2^n≡0 with N.m^n≡0⇒m≡0 2 n 2^n≡0
        ... | ()

        lemma/pred-+ : ∀ m n → m ≢ zero → pred m + n ≡ pred (m + n)
        lemma/pred-+ zero    n m≢zero = ⊥-elim (m≢zero refl)
        lemma/pred-+ (suc m) n m≢zero = refl

  exp₂≤exp₂/cost : ∀ n → ub (U (meta ℕ)) (exp₂ n) (exp₂/cost n)
  exp₂≤exp₂/cost zero    = ub/ret
  exp₂≤exp₂/cost (suc n) =
    ub/bind/const (exp₂/cost n ⊗ exp₂/cost n) ((1 , 1) ⊕ 𝟘) (ub/par (exp₂≤exp₂/cost n) (exp₂≤exp₂/cost n)) λ (r₁ , r₂) →
      ub/step (1 , 1) 𝟘 ub/ret

module Fast where

  exp₂ : cmp (Π (U (meta ℕ)) λ _ → F (U (meta ℕ)))
  exp₂ zero = ret (suc zero)
  exp₂ (suc n) =
    bind (F (U (meta ℕ))) (exp₂ n) λ r →
      step (F (U (meta ℕ))) (1 , 1) (ret (r + r))

  exp₂/correct : Correct exp₂
  exp₂/correct zero    u = refl
  exp₂/correct (suc n) u =
    begin
      exp₂ (suc n)
    ≡⟨⟩
      (bind (F (U (meta ℕ))) (exp₂ n) λ r →
        step (F (U (meta ℕ))) (1 , 1) (ret (r + r)))
    ≡⟨ Eq.cong (bind (F (U (meta ℕ))) (exp₂ n)) (funext (λ r → step/ext (F (U (meta ℕ))) _ (1 , 1) u)) ⟩
      (bind (F (U (meta ℕ))) (exp₂ n) λ r →
        ret (r + r))
    ≡⟨ Eq.cong (λ e → bind (F (U (meta ℕ))) e _) (exp₂/correct n u) ⟩
      (bind (F (U (meta ℕ))) (ret {U (meta ℕ)} (2 ^ n)) λ r →
        ret (r + r))
    ≡⟨⟩
      ret (2 ^ n + 2 ^ n)
    ≡⟨ Eq.cong ret (lemma/2^suc n) ⟩
      ret (2 ^ suc n)
    ∎
      where open ≡-Reasoning

  exp₂/cost : cmp (Π (U (meta ℕ)) λ _ → cost)
  exp₂/cost zero    = 𝟘
  exp₂/cost (suc n) = exp₂/cost n ⊕ ((1 , 1) ⊕ 𝟘)

  exp₂/cost/closed : cmp (Π (U (meta ℕ)) λ _ → cost)
  exp₂/cost/closed n = n , n

  exp₂/cost≡exp₂/cost/closed : ∀ n → exp₂/cost n ≡ exp₂/cost/closed n
  exp₂/cost≡exp₂/cost/closed zero    = refl
  exp₂/cost≡exp₂/cost/closed (suc n) =
    begin
      exp₂/cost (suc n)
    ≡⟨⟩
      exp₂/cost n ⊕ ((1 , 1) ⊕ 𝟘)
    ≡⟨ Eq.cong (λ c → c ⊕ ((1 , 1) ⊕ 𝟘)) (exp₂/cost≡exp₂/cost/closed n) ⟩
      exp₂/cost/closed n ⊕ ((1 , 1) ⊕ 𝟘)
    ≡⟨ Eq.cong (exp₂/cost/closed n ⊕_) (⊕-identityʳ _) ⟩
      exp₂/cost/closed n ⊕ (1 , 1)
    ≡⟨ Eq.cong₂ _,_ (N.+-comm _ 1) (N.+-comm _ 1) ⟩
      exp₂/cost/closed (suc n)
    ∎
      where open ≡-Reasoning

  exp₂≤exp₂/cost : ∀ n → ub (U (meta ℕ)) (exp₂ n) (exp₂/cost n)
  exp₂≤exp₂/cost zero    = ub/ret
  exp₂≤exp₂/cost (suc n) =
    ub/bind/const (exp₂/cost n) ((1 , 1) ⊕ 𝟘) (exp₂≤exp₂/cost n) λ r →
      ub/step (1 , 1) 𝟘 ub/ret

slow≡fast : ◯ (Slow.exp₂ ≡ Fast.exp₂)
slow≡fast u = funext λ n →
  begin
    Slow.exp₂ n
  ≡⟨ Slow.exp₂/correct n u ⟩
    ret (2 ^ n)
  ≡˘⟨ Fast.exp₂/correct n u ⟩
    Fast.exp₂ n
  ∎
    where open ≡-Reasoning
