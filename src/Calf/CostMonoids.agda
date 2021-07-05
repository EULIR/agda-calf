{-# OPTIONS --prop --without-K --rewriting #-}

-- Common cost monoids.

module Calf.CostMonoids where

open import Calf.CostMonoid
open import Data.Product
open import Function
open import Relation.Binary.PropositionalEquality

ℕ-CostMonoid : CostMonoid
ℕ-CostMonoid = record
  { ℂ = ℕ
  ; _+_ = _+_
  ; zero = zero
  ; _≤_ = _≤_
  ; isCostMonoid = record
    { isMonoid = +-0-isMonoid
    ; isCancellative = record { ∙-cancel-≡ = +-cancel-≡ }
    ; isPreorder = ≤-isPreorder
    ; isMonotone = record { ∙-mono-≤ = +-mono-≤ }
    }
  }
  where
    open import Data.Nat
    open import Data.Nat.Properties

ℤ-CostMonoid : CostMonoid
ℤ-CostMonoid = record
  { ℂ = ℤ
  ; _+_ = _+_
  ; zero = 0ℤ
  ; _≤_ = _≤_
  ; isCostMonoid = record
    { isMonoid = +-0-isMonoid
    ; isCancellative = record { ∙-cancel-≡ = +-cancelˡ-≡ , +-cancelʳ-≡ }
    ; isPreorder = ≤-isPreorder
    ; isMonotone = record { ∙-mono-≤ = +-mono-≤ }
    }
  }
  where
    open import Data.Integer
    open import Data.Integer.Properties

    open import Data.Nat using (ℕ)
    import Data.Nat.Properties as N

    open import Algebra.Definitions _≡_

    ⊖-cancelˡ-≡ : ∀ x {y z} → (x ⊖ y) ≈ (x ⊖ z) → y ≈ z
    ⊖-cancelˡ-≡ = {!   !}

    ⊖-cancelʳ-≡ : ∀ {x} y z → (y ⊖ x) ≈ (z ⊖ x) → y ≈ z
    ⊖-cancelʳ-≡ = {!   !}

    +-cancelˡ-≡ : LeftCancellative _+_
    +-cancelˡ-≡ (+_ n) {+_ n₁} {+_ n₂} h = cong +_ (N.+-cancelˡ-≡ n (+-injective h))
    +-cancelˡ-≡ (+_ n) {+_ n₁} { -[1+_] n₂} h with m⊖1+n<m n n₁
    ... | foo = {!   !}
    +-cancelˡ-≡ (+_ n) { -[1+_] n₁} {+_ n₂} h = {!   !}
    +-cancelˡ-≡ (+_ n) { -[1+_] n₁} { -[1+_] n₂} h = cong -[1+_] (N.suc-injective (⊖-cancelˡ-≡ n h))
    +-cancelˡ-≡ (-[1+_] n) {+_ n₁} {+_ n₂} h = cong +_ (⊖-cancelʳ-≡ {ℕ.suc n} n₁ n₂ h)
    +-cancelˡ-≡ (-[1+_] n) {+_ n₁} { -[1+_] n₂} h = {!   !}
    +-cancelˡ-≡ (-[1+_] n) { -[1+_] n₁} {+_ n₂} h = {!   !}
    +-cancelˡ-≡ (-[1+_] n) { -[1+_] n₁} { -[1+_] n₂} h = cong -[1+_] (N.+-cancelˡ-≡ n (N.suc-injective (-[1+-injective h)))

    +-cancelʳ-≡ : RightCancellative _+_
    +-cancelʳ-≡ {x} y z h = +-cancelˡ-≡ x $
      begin
        x + y
      ≡⟨ +-comm x y ⟩
        y + x
      ≡⟨ h ⟩
        z + x
      ≡˘⟨ +-comm x z ⟩
        x + z
      ∎
        where open ≡-Reasoning

ℕ-Work-ParCostMonoid : ParCostMonoid
ℕ-Work-ParCostMonoid = record
  { ℂ = ℕ
  ; _⊕_ = _+_
  ; 𝟘 = 0
  ; _⊗_ = _+_
  ; 𝟙 = 0
  ; _≤_ = _≤_
  ; isParCostMonoid = record
    { isMonoid = +-0-isMonoid
    ; isCommutativeMonoid = +-0-isCommutativeMonoid
    ; isCancellative = record { ∙-cancel-≡ = +-cancel-≡ }
    ; isPreorder = ≤-isPreorder
    ; isMonotone-⊕ = record { ∙-mono-≤ = +-mono-≤ }
    ; isMonotone-⊗ = record { ∙-mono-≤ = +-mono-≤ }
    }
  }
  where
    open import Data.Nat
    open import Data.Nat.Properties

ℕ-Span-ParCostMonoid : ParCostMonoid
ℕ-Span-ParCostMonoid = record
  { ℂ = ℕ
  ; _⊕_ = _+_
  ; 𝟘 = 0
  ; _⊗_ = _⊔_
  ; 𝟙 = 0
  ; _≤_ = _≤_
  ; isParCostMonoid = record
    { isMonoid = +-0-isMonoid
    ; isCommutativeMonoid = ⊔-0-isCommutativeMonoid
    ; isPreorder = ≤-isPreorder
    ; isCancellative = record { ∙-cancel-≡ = +-cancel-≡ }
    ; isMonotone-⊕ = record { ∙-mono-≤ = +-mono-≤ }
    ; isMonotone-⊗ = record { ∙-mono-≤ = ⊔-mono-≤ }
    }
  }
  where
    open import Data.Nat
    open import Data.Nat.Properties

combineParCostMonoids : ParCostMonoid → ParCostMonoid → ParCostMonoid
combineParCostMonoids pcm₁ pcm₂ = record
  { ℂ = ℂ pcm₁ × ℂ pcm₂
  ; _⊕_ = λ (a₁ , a₂) (b₁ , b₂) → _⊕_ pcm₁ a₁ b₁ , _⊕_ pcm₂ a₂ b₂
  ; 𝟘 = 𝟘 pcm₁ , 𝟘 pcm₂
  ; _⊗_ = λ (a₁ , a₂) (b₁ , b₂) → _⊗_ pcm₁ a₁ b₁ , _⊗_ pcm₂ a₂ b₂
  ; 𝟙 = 𝟙 pcm₁ , 𝟙 pcm₂
  ; _≤_ = λ (a₁ , a₂) (b₁ , b₂) → _≤_ pcm₁ a₁ b₁ × _≤_ pcm₂ a₂ b₂
  ; isParCostMonoid = record
    { isMonoid = record
      { isSemigroup = record
        { isMagma = record
          { isEquivalence = isEquivalence
          ; ∙-cong = λ h₁ h₂ →
              cong₂ _,_
                (cong₂ (_⊕_ pcm₁) (cong proj₁ h₁) (cong proj₁ h₂))
                (cong₂ (_⊕_ pcm₂) (cong proj₂ h₁) (cong proj₂ h₂))
          }
        ; assoc = λ (a₁ , a₂) (b₁ , b₂) (c₁ , c₂) → cong₂ _,_ (⊕-assoc pcm₁ a₁ b₁ c₁) (⊕-assoc pcm₂ a₂ b₂ c₂)
        }
      ; identity =
        (λ (a₁ , a₂) → cong₂ _,_ (⊕-identityˡ pcm₁ a₁) (⊕-identityˡ pcm₂ a₂)) ,
        (λ (a₁ , a₂) → cong₂ _,_ (⊕-identityʳ pcm₁ a₁) (⊕-identityʳ pcm₂ a₂))
      }
    ; isCommutativeMonoid = record
      { isMonoid = record
        { isSemigroup = record
          { isMagma = record
            { isEquivalence = isEquivalence
            ; ∙-cong = λ h₁ h₂ →
                cong₂ _,_
                  (cong₂ (_⊗_ pcm₁) (cong proj₁ h₁) (cong proj₁ h₂))
                  (cong₂ (_⊗_ pcm₂) (cong proj₂ h₁) (cong proj₂ h₂))
            }
          ; assoc = λ (a₁ , a₂) (b₁ , b₂) (c₁ , c₂) → cong₂ _,_ (⊗-assoc pcm₁ a₁ b₁ c₁) (⊗-assoc pcm₂ a₂ b₂ c₂)
          }
        ; identity =
          (λ (a₁ , a₂) → cong₂ _,_ (⊗-identityˡ pcm₁ a₁) (⊗-identityˡ pcm₂ a₂)) ,
          (λ (a₁ , a₂) → cong₂ _,_ (⊗-identityʳ pcm₁ a₁) (⊗-identityʳ pcm₂ a₂))
        }
      ; comm = λ (a₁ , a₂) (b₁ , b₂) → cong₂ _,_ (⊗-comm pcm₁ a₁ b₁) (⊗-comm pcm₂ a₂ b₂)
      }
    ; isCancellative = record
      { ∙-cancel-≡ =
        (λ (x₁ , x₂)           h → cong₂ _,_ (⊕-cancelˡ-≡ pcm₁ x₁    (cong proj₁ h)) (⊕-cancelˡ-≡ pcm₂ x₂    (cong proj₂ h))) ,
        (λ (y₁ , y₂) (z₁ , z₂) h → cong₂ _,_ (⊕-cancelʳ-≡ pcm₁ y₁ z₁ (cong proj₁ h)) (⊕-cancelʳ-≡ pcm₂ y₂ z₂ (cong proj₂ h)))
      }
    ; isPreorder = record
      { isEquivalence = isEquivalence
      ; reflexive = λ { refl → ≤-refl pcm₁ , ≤-refl pcm₂ }
      ; trans = λ (h₁ , h₂) (h₁' , h₂') → ≤-trans pcm₁ h₁ h₁' , ≤-trans pcm₂ h₂ h₂'
      }
    ; isMonotone-⊕ = record
      { ∙-mono-≤ = λ (h₁ , h₂) (h₁' , h₂') → ⊕-mono-≤ pcm₁ h₁ h₁' , ⊕-mono-≤ pcm₂ h₂ h₂'
      }
    ; isMonotone-⊗ = record
      { ∙-mono-≤ = λ (h₁ , h₂) (h₁' , h₂') → ⊗-mono-≤ pcm₁ h₁ h₁' , ⊗-mono-≤ pcm₂ h₂ h₂'
      }
    }
  }
  where open ParCostMonoid

ℕ²-ParCostMonoid : ParCostMonoid
ℕ²-ParCostMonoid = combineParCostMonoids ℕ-Work-ParCostMonoid ℕ-Span-ParCostMonoid
