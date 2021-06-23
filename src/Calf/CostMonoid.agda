{-# OPTIONS --prop --without-K --rewriting #-}

-- Definition of a cost monoid.

open import Relation.Binary using (Rel; _Preserves_⟶_; _Preserves₂_⟶_⟶_)

module Calf.CostMonoid where

open import Level using (Level; 0ℓ; suc; _⊔_)
open import Algebra.Core
open import Relation.Binary.PropositionalEquality using (_≡_)


module _ {ℂ : Set} where
  Relation = Rel ℂ 0ℓ

  _≈_ : Relation
  _≈_ = _≡_

  open import Algebra.Definitions _≈_
  open import Algebra.Structures _≈_ public
  open import Relation.Binary.Structures _≈_

  record IsOrderPreserving (_∙_ : Op₂ ℂ) (ε : ℂ) (_≤_ : Relation) : Set where
    field
      isTotalPreorder : IsTotalPreorder _≤_
      z≤c             : {c : ℂ} → ε ≤ c
      ∙-mono-≤        : _∙_ Preserves₂ _≤_ ⟶ _≤_ ⟶ _≤_

    open IsTotalPreorder isTotalPreorder public
      using ()
      renaming (refl to ≤-refl; trans to ≤-trans)

    ∙-monoˡ-≤ : ∀ n → (_∙ n) Preserves _≤_ ⟶ _≤_
    ∙-monoˡ-≤ n m≤o = ∙-mono-≤ m≤o (≤-refl {n})

    ∙-monoʳ-≤ : ∀ n → (n ∙_) Preserves _≤_ ⟶ _≤_
    ∙-monoʳ-≤ n m≤o = ∙-mono-≤ (≤-refl {n}) m≤o

  record IsCostMonoid (_+_ : Op₂ ℂ) (zero : ℂ) (_≤_ : Relation) : Set where
    field
      isMonoid          : IsMonoid _+_ zero
      isOrderPreserving : IsOrderPreserving _+_ zero _≤_

    open IsMonoid isMonoid public
      using ()
      renaming (
        identityˡ to +-identityˡ;
        identityʳ to +-identityʳ;
        assoc to +-assoc
      )

    open IsOrderPreserving isOrderPreserving public
      renaming (
        ∙-mono-≤ to +-mono-≤;
        ∙-monoˡ-≤ to +-monoˡ-≤;
        ∙-monoʳ-≤ to +-monoʳ-≤
      )

  record IsParCostMonoid (_⊕_ : Op₂ ℂ) (𝟘 : ℂ) (_⊗_ : Op₂ ℂ) (𝟙 : ℂ) (_≤₊_ : Relation) (_≤ₓ_ : Relation) : Set where
    field
      isMonoid            : IsMonoid _⊕_ 𝟘
      isCommutativeMonoid : IsCommutativeMonoid _⊗_ 𝟙
      isOrderPreserving₊  : IsOrderPreserving _⊕_ 𝟘 _≤₊_
      isOrderPreservingₓ  : IsOrderPreserving _⊕_ 𝟘 _≤ₓ_
      ⊗-mono-≤ₓ           : _⊗_ Preserves₂ _≤ₓ_ ⟶ _≤ₓ_ ⟶ _≤ₓ_

    open IsMonoid isMonoid public
      using ()
      renaming (
        identityˡ to ⊕-identityˡ;
        identityʳ to ⊕-identityʳ;
        assoc to ⊕-assoc
      )

    open IsCommutativeMonoid isCommutativeMonoid public
      using ()
      renaming (
        identityˡ to ⊗-identityˡ;
        identityʳ to ⊗-identityʳ;
        assoc to ⊗-assoc;
        comm to ⊗-comm
      )

    open IsOrderPreserving isOrderPreserving₊ public
      renaming (
        ≤-refl to ≤₊-refl;
        ≤-trans to ≤₊-trans;
        ∙-mono-≤ to ⊕-mono-≤₊;
        ∙-monoˡ-≤ to ⊕-monoˡ-≤₊;
        ∙-monoʳ-≤ to ⊕-monoʳ-≤₊
      )

    open IsOrderPreserving isOrderPreservingₓ public
      renaming (
        ≤-refl to ≤ₓ-refl;
        ≤-trans to ≤ₓ-trans;
        ∙-mono-≤ to ⊕-mono-≤ₓ;
        ∙-monoˡ-≤ to ⊕-monoˡ-≤ₓ;
        ∙-monoʳ-≤ to ⊕-monoʳ-≤ₓ
      )

record Monoid : Set₁ where
  field
    ℂ        : Set
    _+_      : Op₂ ℂ
    zero     : ℂ
    isMonoid : IsMonoid _+_ zero
  
  open IsMonoid isMonoid

record CostMonoid : Set₁ where
  infixl 6 _+_

  field
    ℂ            : Set
    _+_          : Op₂ ℂ
    zero         : ℂ
    _≤_          : Relation
    isCostMonoid : IsCostMonoid _+_ zero _≤_

  open IsCostMonoid isCostMonoid public

  monoid : Monoid
  monoid = record
    { ℂ = ℂ
    ; _+_ = _+_
    ; zero = zero
    ; isMonoid = isMonoid
    }

record ParCostMonoid : Set₁ where
  infixl 7 _⊗_
  infixl 6 _⊕_
  
  field
    ℂ               : Set
    _⊕_             : Op₂ ℂ
    𝟘               : ℂ
    _⊗_             : Op₂ ℂ
    𝟙               : ℂ
    _≤₊_            : Relation
    _≤ₓ_            : Relation
    isParCostMonoid : IsParCostMonoid _⊕_ 𝟘 _⊗_ 𝟙 _≤₊_ _≤ₓ_

  open IsParCostMonoid isParCostMonoid public

  ⊕-monoid : Monoid
  ⊕-monoid = record
    { ℂ = ℂ
    ; _+_ = _⊕_
    ; zero = 𝟘
    ; isMonoid = isMonoid
    }

  costMonoid-≤₊ : CostMonoid
  costMonoid-≤₊ = record
    { ℂ = ℂ
    ; _+_ = _⊕_
    ; zero = 𝟘
    ; _≤_ = _≤₊_
    ; isCostMonoid = record
      { isMonoid = isMonoid
      ; isOrderPreserving = isOrderPreserving₊
      }
    }

  costMonoid-≤ₓ : CostMonoid
  costMonoid-≤ₓ = record
    { ℂ = ℂ
    ; _+_ = _⊕_
    ; zero = 𝟘
    ; _≤_ = _≤ₓ_
    ; isCostMonoid = record
      { isMonoid = isMonoid
      ; isOrderPreserving = isOrderPreservingₓ
      }
    }

--   -- ⊕-orderedMonoid : OrderedMonoid
--   -- ⊕-orderedMonoid = record
--   --   { ℂ = ℂ
--   --   ; _∙_ = _⊕_
--   --   ; ε = 𝟘
--   --   ; _≤_ = _≤₊_
--   --   ; isOrderedMonoid = IsCostMonoid.isOrderedMonoid isCostMonoid
--   --   }

--   -- ⊗-orderedMonoid : OrderedMonoid
--   -- ⊗-orderedMonoid = record
--   --   { ℂ = ℂ
--   --   ; _∙_ = _⊗_
--   --   ; ε = 𝟙
--   --   ; _≤_ = _≤ₓ_
--   --   ; isOrderedMonoid = IsOrderedCommutativeMonoid.isOrderedMonoid (IsParCostMonoid.isOrderedCommutativeMonoid isParCostMonoid)
--   --   }
