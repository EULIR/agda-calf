{-# OPTIONS --prop --rewriting #-}

module Examples.BinarySearchTree where

open import Calf.CostMonoid
open import Calf.CostMonoids using (ℕ²-ParCostMonoid)

parCostMonoid = ℕ²-ParCostMonoid
open ParCostMonoid parCostMonoid

open import Level using (0ℓ)

open import Calf costMonoid
open import Calf.ParMetalanguage parCostMonoid
open import Calf.Types.Unit
open import Calf.Types.Product
open import Calf.Types.Sum
open import Calf.Types.Bool
open import Calf.Types.Maybe
open import Calf.Types.Nat
open import Calf.Types.List
open import Data.String using (String)
open import Data.Nat as Nat using (_+_; _*_; _<_; _>_; _≤ᵇ_; _<ᵇ_; ⌊_/2⌋; _≡ᵇ_; _≥_)
open import Data.Bool as Bool using (not; _∧_)
import Data.Nat.Properties as Nat

open import Function

open import Relation.Nullary
open import Relation.Nullary.Negation using (contradiction)
open import Relation.Binary
open import Relation.Binary.PropositionalEquality as Eq using (_≡_; refl; _≢_; module ≡-Reasoning; ≢-sym)

variable
  A B C : tp pos
  X Y Z : tp neg
  P Q : val A → tp neg


record ParametricBST (Key : StrictTotalOrder 0ℓ 0ℓ 0ℓ) : Set₁ where
  open StrictTotalOrder Key

  𝕂 : tp pos
  𝕂 = U (meta (StrictTotalOrder.Carrier Key))

  field
    bst : tp pos

    leaf : cmp (F bst)
    node : cmp (Π bst λ t₁ → Π 𝕂 λ k → Π bst λ t₂ → F bst)

    rec :
      cmp
        ( Π (U X) λ _ →
          Π (U (Π bst λ _ → Π (U X) λ _ → Π 𝕂 λ _ → Π bst λ _ → Π (U X) λ _ → X)) λ _ →
          Π bst λ _ → X
        )

  empty : cmp (F bst)
  empty = leaf

  singleton : cmp (Π 𝕂 λ _ → F bst)
  singleton k =
    bind (F bst) empty λ t →
    node t k t

  Split : tp neg
  Split = F (prod⁺ bst (prod⁺ (maybe 𝕂) bst))

  split : cmp (Π bst λ _ → Π 𝕂 λ _ → Split)
  split t k =
    rec
      {X = F (prod⁺ bst (prod⁺ (maybe 𝕂) bst))}
      (bind Split empty λ t →
        ret (t , nothing , t))
      (λ t₁ ih₁ k' t₂ ih₂ →
        case compare k k' of λ
          { (tri< k<k' ¬k≡k' ¬k>k') →
              bind Split ih₁ λ ( t₁₁ , k? , t₁₂ ) →
              bind Split (node t₁₂ k' t₂) λ t →
              ret (t₁₁ , k? , t)
          ; (tri≈ ¬k<k' k≡k' ¬k>k') → ret (t₁ , just k' , t₂)
          ; (tri> ¬k<k' ¬k≡k' k>k') →
              bind Split ih₂ λ ( t₂₁ , k? , t₂₂ ) →
              bind Split (node t₁ k' t₂₁) λ t →
              ret (t , k? , t₂₂)
          })
      t

  find : cmp (Π bst λ _ → Π 𝕂 λ _ → F (maybe 𝕂))
  find t k = bind (F (maybe 𝕂)) (split t k) λ { (_ , k? , _) → ret k? }

  insert : cmp (Π bst λ _ → Π 𝕂 λ _ → F bst)
  insert t k = bind (F bst) (split t k) λ { (t₁ , _ , t₂) → node t₁ k t₂ }


ListBST : (Key : StrictTotalOrder 0ℓ 0ℓ 0ℓ) → ParametricBST Key
ListBST Key =
  record
    { bst = list 𝕂
    ; leaf = ret []
    ; node =
        λ l₁ k l₂ →
          let n = length l₁ + 1 + length l₂ in
          step (F (list 𝕂)) (n , n) (ret (l₁ ++ [ k ] ++ l₂))
    ; rec = λ {X} → rec {X}
    }
  where
    𝕂 : tp pos
    𝕂 = U (meta (StrictTotalOrder.Carrier Key))

    rec : {X : tp neg} →
      cmp
        ( Π (U X) λ _ →
          Π (U (Π (list 𝕂) λ _ → Π (U X) λ _ → Π 𝕂 λ _ → Π (list 𝕂) λ _ → Π (U X) λ _ → X)) λ _ →
          Π (list 𝕂) λ _ → X
        )
    rec {X} z f []      = z
    rec {X} z f (x ∷ l) = step X (1 , 1) (f [] z x l (rec {X} z f l))

RedBlackBST : (Key : StrictTotalOrder 0ℓ 0ℓ 0ℓ) → ParametricBST Key
RedBlackBST Key =
  record
    { bst = rbt
    ; leaf = ret ⟪ leaf ⟫
    ; node = joinMid
    ; rec = λ {X} → rec {X}
    }
  where
    𝕂 : tp pos
    𝕂 = U (meta (StrictTotalOrder.Carrier Key))

    data Color : Set where
      red : Color
      black : Color
    color : tp pos
    color = U (meta Color)

    -- Indexed Red Black Tree
    data IRBT : val color → val nat → Set where
      leaf  : IRBT black zero
      red   : {n : val nat}
        (t₁ : IRBT black n) (k : val 𝕂) (t₂ : IRBT black n)
        → IRBT red n
      black : {n : val nat} {y₁ y₂ : val color}
        (t₁ : IRBT y₁ n) (k : val 𝕂) (t₂ : IRBT y₂ n)
        → IRBT black (suc n)
    irbt : val color → val nat → tp pos
    irbt y n = U (meta (IRBT y n))

    data AlmostRightRBT : (left-color : val color) → val nat → Set where
      violation :
        {n : val nat}
        → IRBT black n → val 𝕂 → IRBT red n
        → AlmostRightRBT red n
      valid :
        {left-color : val color} {n : val nat} {y : val color} → IRBT y n
        → AlmostRightRBT left-color n
    arrbt : val color → val nat → tp pos
    arrbt y n = U (meta (AlmostRightRBT y n))

    data AlmostLeftRBT : (right-color : val color) → val nat → Set where
      violation :
        {n : val nat}
        → IRBT red n → val 𝕂 → IRBT black n
        → AlmostLeftRBT red n
      valid :
        {right-color : val color} {n : val nat} {y : val color} → IRBT y n
        → AlmostLeftRBT right-color n
    alrbt : val color → val nat → tp pos
    alrbt y n = U (meta (AlmostLeftRBT y n))

    joinRight : cmp (
                    Π color λ y₁ → Π nat λ n₁ → Π (irbt y₁ n₁) λ _ →
                    Π 𝕂 λ _ →
                    Π color λ y₂ → Π nat λ n₂ → Π (irbt y₂ n₂) λ _ →
                    Π (U (meta (n₁ > n₂))) λ _ →
                    F (arrbt y₁ n₁)
                  )
    joinRight .red n₁ (red t₁₁ k₁ t₁₂) k y₂ n₂ t₂ n₁>n₂ =
      bind (F (arrbt red n₁)) (joinRight _ _ t₁₂ k _ _ t₂ n₁>n₂) λ
        { (valid {y = red} t') → ret (violation t₁₁ k₁ t')
        ; (valid {y = black} t') → ret (valid (red t₁₁ k₁ t')) }
    joinRight .black (suc n₁) (black t₁₁ k₁ t₁₂) k y₂ n₂ t₂ n₁>n₂ with n₁ Nat.≟ n₂
    joinRight .black (suc n₁) (black t₁₁ k₁ t₁₂) k red n₁ (red t₂₁ k₂ t₂₂) n₁>n₂ | yes refl =
      ret (valid (red (black t₁₁ k₁ t₁₂) k (black t₂₁ k₂ t₂₂)))
    joinRight .black (suc n₁) (black {y₂ = red} t₁₁ k₁ (red t₁₂₁ k₁₂ t₁₂₂)) k black n₁ t₂ n₁>n₂ | yes refl =
      ret (valid (red (black t₁₁ k₁ t₁₂₁) k₁₂ (black t₁₂₂ k t₂)))
    joinRight .black (suc n₁) (black {y₂ = black} t₁₁ k₁ t₁₂) k black n₁ t₂ n₁>n₂ | yes refl =
      ret (valid (black t₁₁ k₁ (red t₁₂ k t₂)))
    ... | no n₁≢n₂ =
      bind (F (arrbt black (suc n₁))) (joinRight _ _ t₁₂ k _ _ t₂ (Nat.≤∧≢⇒< (Nat.≤-pred n₁>n₂) (≢-sym n₁≢n₂))) λ
        { (violation t'₁ k' (red t'₂₁ k'₂ t'₂₂)) → ret (valid (red (black t₁₁ k₁ t'₁) k' (black t'₂₁ k'₂ t'₂₂)))
        ; (valid t') → ret (valid (black t₁₁ k₁ t'))  }

    joinLeft : cmp (
                    Π color λ y₁ → Π nat λ n₁ → Π (irbt y₁ n₁) λ _ →
                    Π 𝕂 λ _ →
                    Π color λ y₂ → Π nat λ n₂ → Π (irbt y₂ n₂) λ _ →
                    Π (U (meta (n₁ < n₂))) λ _ →
                    F (alrbt y₂ n₂)
                  )
    joinLeft y₁ n₁ t₁ k .red n₂ (red t₂₁ k₁ t₂₂) n₁<n₂ =
      bind (F (alrbt red n₂)) (joinLeft _ _ t₁ k _ _ t₂₁ n₁<n₂) λ
      { (valid {y = red} t') → ret (violation t' k₁ t₂₂)
      ; (valid {y = black} t') → ret (valid (red t' k₁ t₂₂)) }
    joinLeft y₁ n₁ t₁ k .black (suc n₂) (black {y₁ = c} t₂₁ k₁ t₂₂) n₁<n₂ with n₁ Nat.≟ n₂
    joinLeft red n₁ (red t₁₁ k₁ t₁₂) k .black (suc n₁) (black t₂₁ k₂ t₂₂) n₁<n₂ | yes refl =
      ret (valid (red (black t₁₁ k₁ t₁₂) k (black t₂₁ k₂ t₂₂)))
    joinLeft black n₁ t₁ k .black (suc n₁) (black {y₁ = red} (red t₂₁₁ k₁₁ t₂₁₂) k₁ t₂₂) n₁<n₂ | yes refl =
      ret (valid (red (black t₁ k t₂₁₁) k₁₁ (black t₂₁₂ k₁ t₂₂)))
    joinLeft black n₁ t₁ k .black (suc n₁) (black {y₁ = black} t₂₁ k₁ t₂₂) n₁<n₂ | yes refl =
      ret (valid (black (red t₁ k t₂₁) k₁ t₂₂))
    ... | no n₁≢n₂ =
      bind (F (alrbt black (suc n₂))) (joinLeft _ _ t₁ k _ _ t₂₁ (Nat.≤∧≢⇒< (Nat.≤-pred n₁<n₂) n₁≢n₂)) λ
       { (violation (red t'₁₁ k'₁ t'₁₂) k' t'₂) → ret (valid (red (black t'₁₁ k'₁ t'₁₂) k' (black t'₂ k₁ t₂₂)))
       ; (valid t') → ret (valid (black t' k₁ t₂₂)) }

    record RBT : Set where
      pattern
      constructor ⟪_⟫
      field
        {y} : val color
        {n} : val nat
        t : val (irbt y n)
    rbt : tp pos
    rbt = U (meta RBT)

    i-joinMid :
      cmp
        ( Π color λ y₁ → Π nat λ n₁ → Π (irbt y₁ n₁) λ _ →
          Π 𝕂 λ _ →
          Π color λ y₂ → Π nat λ n₂ → Π (irbt y₂ n₂) λ _ →
          F rbt
        )
    i-joinMid y₁ n₁ t₁ k y₂ n₂ t₂ with Nat.<-cmp n₁ n₂
    i-joinMid red n₁ t₁ k y₂ n₂ t₂ | tri≈ ¬n₁<n₂ refl ¬n₁>n₂ = ret ⟪ (black t₁ k t₂) ⟫
    i-joinMid black n₁ t₁ k red n₂ t₂ | tri≈ ¬n₁<n₂ refl ¬n₁>n₂ = ret ⟪ (black t₁ k t₂) ⟫
    i-joinMid black n₁ t₁ k black n₂ t₂ | tri≈ ¬n₁<n₂ refl ¬n₁>n₂ = ret ⟪ (red t₁ k t₂) ⟫
    ... | tri< n₁<n₂ n₁≢n₂ ¬n₁>n₂ =
      bind (F rbt) (joinLeft _ _ t₁ k _ _ t₂ n₁<n₂) λ
        { (violation t'₁ k' t'₂) → ret ⟪ (black t'₁ k' t'₂) ⟫
        ; (valid t') → ret ⟪ t' ⟫}
    ... | tri> ¬n₁<n₂ n₁≢n₂ n₁>n₂ =
      bind (F rbt) (joinRight _ _ t₁ k _ _ t₂ n₁>n₂) λ
        { (violation t'₁ k' t'₂) → ret ⟪ black t'₁ k' t'₂ ⟫
        ; (valid t') → ret ⟪ t' ⟫ }

    joinMid : cmp (Π rbt λ _ → Π 𝕂 λ _ → Π rbt λ _ → F rbt)
    joinMid ⟪ t₁ ⟫ k ⟪ t₂ ⟫ = i-joinMid _ _ t₁ k _ _ t₂

    i-rec : {X : tp neg} →
      cmp
        ( Π (U X) λ _ →
          Π
            ( U
              ( Π color λ y₁ → Π nat λ n₁ → Π (irbt y₁ n₁) λ _ → Π (U X) λ _ →
                Π 𝕂 λ _ →
                Π color λ y₂ → Π nat λ n₂ → Π (irbt y₂ n₂) λ _ → Π (U X) λ _ →
                X
              )
            ) λ _ →
          Π color λ y → Π nat λ n → Π (irbt y n) λ _ →
          X
        )
    i-rec {X} z f .black .zero    leaf            = z
    i-rec {X} z f .red   n        (red   t₁ k t₂) =
      f
        _ _ t₁ (i-rec {X} z f _ _ t₁)
        k
        _ _ t₂ (i-rec {X} z f _ _ t₂)
    i-rec {X} z f .black .(suc _) (black t₁ k t₂) =
      f
        _ _ t₁ (i-rec {X} z f _ _ t₁)
        k
        _ _ t₂ (i-rec {X} z f _ _ t₂)

    rec : {X : tp neg} →
      cmp
        ( Π (U X) λ _ →
          Π (U (Π rbt λ _ → Π (U X) λ _ → Π 𝕂 λ _ → Π rbt λ _ → Π (U X) λ _ → X)) λ _ →
          Π rbt λ _ → X
        )
    rec {X} z f ⟪ t ⟫ =
      i-rec {X}
        z
        (λ _ _ t₁ ih₁ k _ _ t₂ ih₂ → f ⟪ t₁ ⟫ ih₁ k ⟪ t₂ ⟫ ih₂)
        _ _ t

module Ex/NatSet where
  open ParametricBST (ListBST Nat.<-strictTotalOrder)

  example : cmp Split
  example =
    bind Split (singleton 1) λ t₁ →
    bind Split (insert t₁ 2) λ t₁ →
    bind Split (singleton 4) λ t₂ →
    bind Split (node t₁ 3 t₂) λ t →
    split t 2

  -- run Ctrl-C Ctrl-N here
  compute : cmp Split
  compute = ret {!   !}

module Ex/NatStringDict where
  strictTotalOrder : StrictTotalOrder 0ℓ 0ℓ 0ℓ
  strictTotalOrder =
    record
      { Carrier = ℕ × String
      ; _≈_ = λ (n₁ , _) (n₂ , _) → n₁ ≡ n₂
      ; _<_ = λ (n₁ , _) (n₂ , _) → n₁ < n₂
      ; isStrictTotalOrder =
          record
            { isEquivalence =
                record
                  { refl = Eq.refl
                  ; sym = Eq.sym
                  ; trans = Eq.trans
                  }
            ; trans = Nat.<-trans
            ; compare = λ (n₁ , _) (n₂ , _) → Nat.<-cmp n₁ n₂
            }
      }

  open ParametricBST (RedBlackBST strictTotalOrder)

  example : cmp Split
  example =
    bind Split (singleton (1 , "red")) λ t₁ →
    bind Split (insert t₁ (2 , "orange")) λ t₁ →
    bind Split (singleton (4 , "green")) λ t₂ →
    bind Split (node t₁ (3 , "yellow") t₂) λ t →
    split t (2 , "")

  -- run Ctrl-C Ctrl-N here
  compute : cmp Split
  compute = {! example  !}
