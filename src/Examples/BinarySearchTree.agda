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
open import Calf.Types.Maybe
open import Calf.Types.Nat
open import Data.String using (String)
open import Data.Nat as Nat using (_+_; _<_)
import Data.Nat.Properties as Nat

open import Function

open import Relation.Nullary
open import Relation.Binary
open import Relation.Binary.PropositionalEquality as Eq using (_≡_; refl; _≢_; module ≡-Reasoning)

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

  split : cmp (Π bst λ _ → Π 𝕂 λ _ → F (prod bst (prod (maybe 𝕂) bst)))
  split t k =
    rec
      {X = F (prod bst (prod (maybe 𝕂) bst))}
      (bind (F (prod bst (prod (maybe 𝕂) bst))) empty λ t →
        ret (t , nothing , t))
      (λ t₁ ih₁ k' t₂ ih₂ →
        case compare k k' of λ
          { (tri< k<k' ¬k≡k' ¬k>k') →
              bind (F (prod bst (prod (maybe 𝕂) bst))) ih₁ λ ( t₁₁ , k? , t₁₂ ) →
              bind (F (prod bst (prod (maybe 𝕂) bst))) (node t₁₂ k' t₂) λ t →
              ret (t₁₁ , k? , t)
          ; (tri≈ ¬k<k' k≡k' ¬k>k') → ret (t₁ , just k' , t₂)
          ; (tri> ¬k<k' ¬k≡k' k>k') → {!   !}
          })
      t

  find : cmp (Π bst λ _ → Π 𝕂 λ _ → F (maybe 𝕂))
  find t k = bind (F (maybe 𝕂)) (split t k) λ { (_ , k? , _) → ret k? }

  insert : cmp (Π bst λ _ → Π 𝕂 λ _ → F bst)
  insert t k = bind (F bst) (split t k) λ { (t₁ , _ , t₂) → node t₁ k t₂ }


RedBlackBST : (Key : StrictTotalOrder 0ℓ 0ℓ 0ℓ) → ParametricBST Key
RedBlackBST Key =
  record
    { bst = rbt
    ; leaf = ret leaf
    ; node = joinMid
    ; rec = λ {X} → rec {X}
    }
  where
    open StrictTotalOrder Key

    𝕂 : tp pos
    𝕂 = U (meta Carrier)

    data RBT : Set where
      leaf  : RBT
      red   : (t₁ : RBT) (k : val 𝕂) (t₂ : RBT) → RBT
      black : (t₁ : RBT) (k : val 𝕂) (t₂ : RBT) → RBT
    rbt : tp pos
    rbt = U (meta RBT)

    -- Just Join for Parallel Ordered Sets (Blelloch, Ferizovic, and Sun)
    -- https://diderot.one/courses/121/books/492/chapter/6843
    joinMid : cmp (Π rbt λ _ → Π 𝕂 λ _ → Π rbt λ _ → F rbt)
    joinMid t₁ k t₂ = {!   !}

    rec : {X : tp neg} →
      cmp
        ( Π (U X) λ _ →
          Π (U (Π rbt λ _ → Π (U X) λ _ → Π 𝕂 λ _ → Π rbt λ _ → Π (U X) λ _ → X)) λ _ →
          Π rbt λ _ → X
        )
    rec {X} z f leaf = z
    rec {X} z f (red   t₁ k t₂) = f t₁ (rec {X} z f t₁) k t₂ (rec {X} z f t₂)
    rec {X} z f (black t₁ k t₂) = f t₁ (rec {X} z f t₁) k t₂ (rec {X} z f t₂)


module Ex/NatSet where
  open ParametricBST (RedBlackBST Nat.<-strictTotalOrder)

  example : cmp (F (prod bst (prod (maybe 𝕂) bst)))
  example =
    bind (F (prod bst (prod (maybe 𝕂) bst))) (singleton 1) λ t₁ →
    bind (F (prod bst (prod (maybe 𝕂) bst))) (insert t₁ 2) λ t₁ →
    bind (F (prod bst (prod (maybe 𝕂) bst))) (singleton 4) λ t₂ →
    bind (F (prod bst (prod (maybe 𝕂) bst))) (node t₁ 3 t₂) λ t →
    split t 2

  -- run Ctrl-C Ctrl-N here
  compute : cmp (F (prod bst (prod (maybe 𝕂) bst)))
  compute = {! example  !}

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

  example : cmp (F (prod bst (prod (maybe 𝕂) bst)))
  example =
    bind (F (prod bst (prod (maybe 𝕂) bst))) (singleton (1 , "red")) λ t₁ →
    bind (F (prod bst (prod (maybe 𝕂) bst))) (insert t₁ (2 , "orange")) λ t₁ →
    bind (F (prod bst (prod (maybe 𝕂) bst))) (singleton (4 , "green")) λ t₂ →
    bind (F (prod bst (prod (maybe 𝕂) bst))) (node t₁ (3 , "yellow") t₂) λ t →
    split t (2 , "")

  -- run Ctrl-C Ctrl-N here
  compute : cmp (F (prod bst (prod (maybe 𝕂) bst)))
  compute = {! example  !}
