{-# OPTIONS --prop --rewriting #-}

module cbv where

open import framework
open import Agda.Builtin.Sigma

postulate
  𝒱 : □
  [_] : 𝒱 → tp pos
  _→cbv_ : 𝒱 → 𝒱 → 𝒱
  cbv/bool : 𝒱

  [→cbv] : ∀ {α β} → [ α →cbv β ] ≡ U (Πc [ α ] λ _ → F [ β ])
  {-# REWRITE [→cbv] #-}

  [cbv/bool] : [ cbv/bool ] ≡ boolc
  {-# REWRITE [cbv/bool] #-}

infix 10 ⊢_

⊢_ : 𝒱 → □
⊢ β = cmp (F [ β ])

_⊢_ : 𝒱 → 𝒱 → □
α ⊢ β = val [ α ] → ⊢ β

lam : (α β : 𝒱) → α ⊢ β → ⊢ α →cbv β
lam _ β M = ret λ x → ▷/inv (M x)

app : (α β : 𝒱) → ⊢ α →cbv β → ⊢ α → ⊢ β
app α β M N =
  bind (F [ β ]) N λ x →
  bind (F _) M λ f →
  ▷/dir (f x)

tt' : ⊢ cbv/bool
tt' = ret (►/inv tt)
--
fun : ⊢ cbv/bool →cbv cbv/bool
fun = lam cbv/bool cbv/bool λ x → bind (F [ cbv/bool ]) (►/dir x) λ b → tt'

test = app cbv/bool cbv/bool fun tt'

_ : ∀ {α β f u} → app α β (lam α β f) (ret u) ≡ step (F [ β ]) (f u)
_ = refl
