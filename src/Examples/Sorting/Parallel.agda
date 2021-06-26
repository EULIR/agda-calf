{-# OPTIONS --prop --rewriting #-}

module Examples.Sorting.Parallel where

open import Calf.CostMonoid
open import Calf.CostMonoids using (ℕ²-ParCostMonoid)

parCostMonoid = ℕ²-ParCostMonoid
open ParCostMonoid parCostMonoid
  renaming (
    _≤_ to _P≤_;
    ≤-refl to P≤-refl;
    ≤-trans to P≤-trans;
    module ≤-Reasoning to P≤-Reasoning
  )

open import Calf costMonoid
open import Calf.ParMetalanguage parCostMonoid
open import Calf.Types.Bool
open import Calf.Types.List as List

open import Relation.Nullary
open import Relation.Binary
open import Relation.Binary.PropositionalEquality as Eq using (_≡_; refl; module ≡-Reasoning)
open import Data.Product using (_×_; _,_; proj₁; proj₂; ∃)
open import Data.Sum using (inj₁; inj₂)
open import Data.Empty
open import Function
open import Data.Nat as Nat using (ℕ; zero; suc; z≤n; s≤s; _+_; _*_; _^_; ⌊_/2⌋; ⌈_/2⌉; _⊔_)
open import Data.Nat.Properties as N using (module ≤-Reasoning)

private
  variable
    α : Set

record Comparable : Set₁ where
  field
    A : tp pos
    _≤_ : val A → val A → Set
    _≤ᵇ_ : val A → val A → cmp (F bool)
    ≤ᵇ-reflects-≤ : ∀ {x y b} → ◯ ((x ≤ᵇ y) ≡ ret b → Reflects (x ≤ y) b)
    ≤-refl : Reflexive _≤_
    ≤-trans : Transitive _≤_
    ≤-total : Total _≤_
    ≤-antisym : Antisymmetric _≡_ _≤_
    h-cost : (x y : val A) → ub bool (x ≤ᵇ y) (1 , 1)

NatComparable : Comparable
NatComparable = record
  { A = U (meta ℕ)
  ; _≤_ = _≤_
  ; _≤ᵇ_ = λ x y → step' (F bool) (1 , 1) (ret (x ≤ᵇ y))
  ; ≤ᵇ-reflects-≤ = reflects
  ; ≤-refl = ≤-refl
  ; ≤-trans = ≤-trans
  ; ≤-total = ≤-total
  ; ≤-antisym = ≤-antisym
  ; h-cost = λ _ _ → ub/step (1 , 1) 𝟘 ub/ret
  }
  where
    open import Data.Nat
    open import Data.Nat.Properties

    ret-injective : ∀ {𝕊 v₁ v₂} → ret {U (meta 𝕊)} v₁ ≡ ret {U (meta 𝕊)} v₂ → v₁ ≡ v₂
    ret-injective {𝕊} = Eq.cong (λ e → bind {U (meta 𝕊)} (meta 𝕊) e id)

    reflects : ∀ {m n b} → ◯ (step' (F bool) (1 , 1) (ret (m ≤ᵇ n)) ≡ ret {bool} b → Reflects (m ≤ n) b)
    reflects {m} {n} {b} u h with ret-injective (Eq.subst (_≡ ret b) (step'/ext (F bool) (ret (m ≤ᵇ n)) (1 , 1) u) h)
    ... | refl = ≤ᵇ-reflects-≤ m n

module Core (M : Comparable) where
  open Comparable M

  open import Data.List.Relation.Binary.Permutation.Propositional public
  open import Data.List.Relation.Binary.Permutation.Propositional.Properties renaming (++⁺ to ++⁺-↭) public
  open import Data.List.Relation.Unary.All public
  open import Data.List.Relation.Unary.All.Properties using () renaming (++⁺ to ++⁺-All) public
  open import Data.List.Relation.Unary.Any using (Any; here; there)

  _≤*_ : val A → val (list A) → Set
  _≤*_ x = All (x ≤_)

  ≤-≤* : ∀ {x₁ x₂ l} → x₁ ≤ x₂ → x₂ ≤* l → x₁ ≤* l
  ≤-≤* x₁≤x₂ = map (≤-trans x₁≤x₂)

  data Sorted : val (list A) → Set where
    [] : Sorted []
    _∷_ : ∀ {y ys} → y ≤* ys → Sorted ys → Sorted (y ∷ ys)

  short-sorted : {l : val (list A)} → length l Nat.≤ 1 → Sorted l
  short-sorted {[]} _ = []
  short-sorted {_ ∷ []} _ = [] ∷ []
  short-sorted {_ ∷ _ ∷ _} (s≤s ())

  unique-sorted : ∀ {l'₁ l'₂} → Sorted l'₁ → Sorted l'₂ → l'₁ ↭ l'₂ → l'₁ ≡ l'₂
  unique-sorted []             []             ↭ = refl
  unique-sorted []             (h₂ ∷ sorted₂) ↭ = ⊥-elim (¬x∷xs↭[] (↭-sym ↭))
  unique-sorted (h₁ ∷ sorted₁) []             ↭ = ⊥-elim (¬x∷xs↭[] ↭)
  unique-sorted (h₁ ∷ sorted₁) (h₂ ∷ sorted₂) ↭ with
    ≤-antisym
      (lookup (≤-refl ∷ h₁) (Any-resp-↭ (↭-sym ↭) (here refl)))
      (lookup (≤-refl ∷ h₂) (Any-resp-↭ (↭) (here refl)))
  ... | refl = Eq.cong (_ ∷_) (unique-sorted sorted₁ sorted₂ (drop-∷ ↭))

  SortedOf : val (list A) → val (list A) → Set
  SortedOf l l' = l ↭ l' × Sorted l'

  SortResult : cmp (Π (list A) λ _ → F (list A)) → val (list A) → Set
  SortResult sort l = ◯ (∃ λ l' → sort l ≡ ret l' × SortedOf l l')

  IsSort : cmp (Π (list A) λ _ → F (list A)) → Set
  IsSort sort = ∀ l → SortResult sort l

test/forward  = 1 ∷ 2 ∷ 3 ∷ 4 ∷ 5 ∷ 6 ∷ 7 ∷ 8 ∷ 9 ∷ 10 ∷ 11 ∷ 12 ∷ 13 ∷ 14 ∷ 15 ∷ 16 ∷ []
test/backward = 16 ∷ 15 ∷ 14 ∷ 13 ∷ 12 ∷ 11 ∷ 10 ∷ 9 ∷ 8 ∷ 7 ∷ 6 ∷ 5 ∷ 4 ∷ 3 ∷ 2 ∷ 1 ∷ []
test/shuffled = 4 ∷ 8 ∷ 12 ∷ 16 ∷ 13 ∷ 3 ∷ 5 ∷ 14 ∷ 9 ∷ 6 ∷ 7 ∷ 10 ∷ 11 ∷ 1 ∷ 2 ∷ 15 ∷ []

module InsertionSort (M : Comparable) where
  open Comparable M
  open Core M

  insert : cmp (Π A λ _ → Π (list A) λ _ → F (list A))
  insert x []       = ret [ x ]
  insert x (y ∷ ys) =
    bind (F (list A)) (x ≤ᵇ y)
      λ { false → bind (F (list A)) (insert x ys) (ret ∘ (y ∷_))
        ; true  → ret (x ∷ (y ∷ ys)) }

  insert/correct : ∀ x l → Sorted l → ◯ (∃ λ l' → insert x l ≡ ret l' × SortedOf (x ∷ l) l')
  insert/correct x []       []       u = [ x ] , refl , refl , [] ∷ []
  insert/correct x (y ∷ ys) (h ∷ hs) u with h-cost x y
  insert/correct x (y ∷ ys) (h ∷ hs) u | ub/intro {q = q} b _ h-eq rewrite eq/ref h-eq
    with ≤ᵇ-reflects-≤ u (Eq.trans (eq/ref h-eq) (step'/ext (F bool) (ret b) q u)) | ≤-total x y
  insert/correct x (y ∷ ys) (h ∷ hs) u | ub/intro {q = q} false _ _ | ofⁿ ¬x≤y | inj₁ x≤y = ⊥-elim (¬x≤y x≤y)
  insert/correct x (y ∷ ys) (h ∷ hs) u | ub/intro {q = q} false _ _ | ofⁿ ¬x≤y | inj₂ x≤y =
    let (ys' , h-ys' , x∷ys↭ys' , sorted-ys') = insert/correct x ys hs u in
    y ∷ ys' , (
      let open ≡-Reasoning in
      begin
        step' (F (list A)) q (bind (F (list A)) (insert x ys) (ret ∘ (y ∷_)))
      ≡⟨ step'/ext (F (list A)) (bind (F (list A)) (insert x ys) (ret ∘ (y ∷_))) q u ⟩
        bind (F (list A)) (insert x ys) (ret ∘ (y ∷_))
      ≡⟨ Eq.cong (λ e → bind (F (list A)) e (ret ∘ (y ∷_))) h-ys' ⟩
        ret (y ∷ ys')
      ∎
    ) , (
      let open PermutationReasoning in
      begin
        x ∷ y ∷ ys
      <<⟨ refl ⟩
        y ∷ (x ∷ ys)
      <⟨ x∷ys↭ys' ⟩
        y ∷ ys'
      ∎
    ) , All-resp-↭ x∷ys↭ys' (x≤y ∷ h) ∷ sorted-ys'
  insert/correct x (y ∷ ys) (h ∷ hs) u | ub/intro {q = q} true _ _ | ofʸ x≤y | _ =
    x ∷ (y ∷ ys) , step'/ext (F (list A)) (ret _) q u , refl , (x≤y ∷ ≤-≤* x≤y h) ∷ (h ∷ hs)

  insert/length : ∀ x l (κ : ℕ → α) → bind (meta α) (insert x l) (κ ∘ length) ≡ κ (suc (length l))
  insert/length x []       κ = refl
  insert/length x (y ∷ ys) κ with h-cost x y
  ... | ub/intro false _ h-eq rewrite eq/ref h-eq = insert/length x ys (κ ∘ suc)
  ... | ub/intro true  _ h-eq rewrite eq/ref h-eq = refl

  insert/cost : cmp (Π A λ _ → Π (list A) λ _ → cost)
  insert/cost x []       = 𝟘
  insert/cost x (y ∷ ys) with h-cost x y
  ... | ub/intro {q = q} false q≤1 h-eq = q ⊕ (insert/cost x ys ⊕ 𝟘)
  ... | ub/intro {q = q} true  q≤1 h-eq = q ⊕ 𝟘

  insert/cost/closed : cmp (Π A λ _ → Π (list A) λ _ → cost)
  insert/cost/closed x l = length l , length l
 
  insert/cost≤insert/cost/closed : ∀ x l → insert/cost x l P≤ insert/cost/closed x l
  insert/cost≤insert/cost/closed x []       = P≤-refl
  insert/cost≤insert/cost/closed x (y ∷ ys) with h-cost x y
  ... | ub/intro {q = q} false q≤1 h-eq =
    Eq.subst (λ n → (q ⊕ n) P≤ (suc (length ys) , suc (length ys))) (Eq.sym (⊕-identityʳ (insert/cost x ys))) (
      P≤-trans
        (⊕-monoˡ-≤ _ q≤1)
        (s≤s (proj₁ (insert/cost≤insert/cost/closed x ys)) ,
         s≤s (proj₂ (insert/cost≤insert/cost/closed x ys)))
    )
  ... | ub/intro {q = q} true  q≤1 h-eq =
    Eq.subst (_P≤ (suc (length ys) , suc (length ys))) (Eq.sym (⊕-identityʳ q)) (
      P≤-trans q≤1 (s≤s z≤n , s≤s z≤n)
    )

  insert≤insert/cost : ∀ x l → ub (list A) (insert x l) (insert/cost x l)
  insert≤insert/cost x []       = ub/ret
  insert≤insert/cost x (y ∷ ys) with h-cost x y
  ... | ub/intro {q = q} false q≤1 h-eq rewrite eq/ref h-eq =
    ub/step q (insert/cost x ys ⊕ 𝟘) (ub/bind/const (insert/cost x ys) 𝟘 (insert≤insert/cost x ys) λ _ → ub/ret)
  ... | ub/intro {q = q} true  q≤1 h-eq rewrite eq/ref h-eq =
    ub/step q 𝟘 ub/ret

  insert≤insert/cost/closed : ∀ x l → ub (list A) (insert x l) (insert/cost/closed x l)
  insert≤insert/cost/closed x l = ub/relax (insert/cost≤insert/cost/closed x l) (insert≤insert/cost x l)

  sort : cmp (Π (list A) λ _ → F (list A))
  sort []       = ret []
  sort (x ∷ xs) = bind (F (list A)) (sort xs) (insert x)

  sort/correct : IsSort sort
  sort/correct []       u = [] , refl , refl , []
  sort/correct (x ∷ xs) u =
    let (xs'   , h-xs'   , xs↭xs'     , sorted-xs'  ) = sort/correct xs u in
    let (x∷xs' , h-x∷xs' , x∷xs↭x∷xs' , sorted-x∷xs') = insert/correct x xs' sorted-xs' u in
    x∷xs' , (
      let open ≡-Reasoning in
      begin
        sort (x ∷ xs)
      ≡⟨⟩
        bind (F (list A)) (sort xs) (insert x)
      ≡⟨ Eq.cong (λ e → bind (F (list A)) e (insert x)) h-xs' ⟩
        bind (F (list A)) (ret {list A} xs') (insert x)
      ≡⟨⟩
        insert x xs'
      ≡⟨ h-x∷xs' ⟩
        ret x∷xs'
      ∎
    ) , (
      let open PermutationReasoning in
      begin
        x ∷ xs
      <⟨ xs↭xs' ⟩
        x ∷ xs'
      ↭⟨ x∷xs↭x∷xs' ⟩
        x∷xs'
      ∎
    ) , sorted-x∷xs'

  sort/length : ∀ l (κ : ℕ → α) → bind (meta α) (sort l) (κ ∘ length) ≡ κ (length l)
  sort/length []       κ = refl
  sort/length (x ∷ xs) κ =
    begin
      bind _ (sort (x ∷ xs)) (κ ∘ length)
    ≡⟨⟩
      bind _ (bind (F (list A)) (sort xs) (insert x)) (κ ∘ length)
    ≡⟨⟩
      bind _ (sort xs) (λ xs' → bind (meta _) (insert x xs') (κ ∘ length))
    ≡⟨ Eq.cong (bind _ (sort xs)) (funext λ xs' → insert/length x xs' κ)  ⟩
      bind _ (sort xs) (λ xs' → κ (suc (length xs')))
    ≡⟨ sort/length xs (κ ∘ suc) ⟩
      κ (length (x ∷ xs))
    ∎
      where open ≡-Reasoning

  sort/cost : cmp (Π (list A) λ _ → cost)
  sort/cost []       = 𝟘
  sort/cost (x ∷ xs) = bind cost (sort xs) (λ xs' → sort/cost xs ⊕ insert/cost/closed x xs')

  sort/cost/closed : cmp (Π (list A) λ _ → cost)
  sort/cost/closed l = length l ^ 2 , length l ^ 2

  sort/cost≤sort/cost/closed : ∀ l → sort/cost l P≤ sort/cost/closed l
  sort/cost≤sort/cost/closed []       = P≤-refl
  sort/cost≤sort/cost/closed (x ∷ xs) =
    let open P≤-Reasoning in
    begin
      sort/cost (x ∷ xs)
    ≡⟨⟩
      bind cost (sort xs) (λ xs' → sort/cost xs ⊕ insert/cost/closed x xs')
    ≡⟨ sort/length xs (λ n → sort/cost xs ⊕ (n , n)) ⟩
      sort/cost xs ⊕ insert/cost/closed x xs
    ≤⟨ ⊕-monoˡ-≤ (insert/cost/closed x xs) (sort/cost≤sort/cost/closed xs) ⟩
      sort/cost/closed xs ⊕ insert/cost/closed x xs
    ≡⟨⟩
      (length xs ^ 2 , length xs ^ 2) ⊕ (length xs , length xs)
    ≤⟨ lemma/arithmetic (length xs) , lemma/arithmetic (length xs) ⟩
      length (x ∷ xs) ^ 2 , length (x ∷ xs) ^ 2
    ≡⟨⟩
      sort/cost/closed (x ∷ xs)
    ∎
      where
        lemma/arithmetic : ∀ n → n ^ 2 + n Nat.≤ suc n ^ 2
        lemma/arithmetic n =
          begin
            n ^ 2 + n
          ≡⟨ N.+-comm (n ^ 2) n ⟩
            n + n ^ 2
          ≡⟨ Eq.cong (λ m → n + n * m) (N.*-identityʳ n) ⟩
            n + n * n
          ≤⟨ N.m≤n+m (n + n * n) (suc n) ⟩
            suc n + (n + n * n)
          ≡⟨⟩
            suc (n + (n + n * n))
          ≡˘⟨ Eq.cong (λ m → suc (n + m)) (N.*-suc n n) ⟩
            suc (n + n * suc n)
          ≡˘⟨ Eq.cong (λ m → suc (m + n * suc m)) (N.*-identityʳ n) ⟩
            suc (n * 1 + n * suc (n * 1))
          ≡⟨⟩
            suc n ^ 2
          ∎
          where open ≤-Reasoning

  sort≤sort/cost : ∀ l → ub (list A) (sort l) (sort/cost l)
  sort≤sort/cost []       = ub/ret
  sort≤sort/cost (x ∷ xs) = ub/bind (sort/cost xs) (insert/cost/closed x) (sort≤sort/cost xs) (insert≤insert/cost/closed x)

  sort≤sort/cost/closed : ∀ l → ub (list A) (sort l) (sort/cost/closed l)
  sort≤sort/cost/closed l = ub/relax (sort/cost≤sort/cost/closed l) (sort≤sort/cost l)

module Ex/InsertionSort where
  module Sort = InsertionSort NatComparable

  list' = list (U (meta ℕ))

  ex/insert : cmp (F list')
  ex/insert = Sort.insert 3 (1 ∷ 2 ∷ 4 ∷ [])

  ex/sort : cmp (F list')
  ex/sort = Sort.sort (1 ∷ 5 ∷ 3 ∷ 1 ∷ 2 ∷ [])

  ex/sort/forward : cmp (F list')
  ex/sort/forward = Sort.sort test/forward  -- cost: 15 , 15

  ex/sort/backward : cmp (F list')
  ex/sort/backward = Sort.sort test/backward  -- cost: 120 , 120

  ex/sort/shuffled : cmp (F list')
  ex/sort/shuffled = Sort.sort test/shuffled  -- cost: 76 , 76

module Log2 where
  private
    aux : (P : ℕ → Set) → P zero → P (suc zero) → ((n : ℕ) → P ⌈ suc (suc n) /2⌉ → P (suc (suc n))) →
      (n : ℕ) → (m : ℕ) → m Nat.≤ n → P m
    aux P bc₀ bc₁ is n zero h = bc₀
    aux P bc₀ bc₁ is n (suc zero) h = bc₁
    aux P bc₀ bc₁ is (suc (suc n)) (suc (suc m)) (s≤s (s≤s h)) =
      is m (aux P bc₀ bc₁ is (suc n) ⌈ suc (suc m) /2⌉ (s≤s (N.≤-trans (N.⌈n/2⌉≤n m) h)))

  strong-induction : (P : ℕ → Set) → P zero → P (suc zero) → ((n : ℕ) → P ⌈ suc (suc n) /2⌉ → P (suc (suc n))) → (n : ℕ) → P n
  strong-induction P bc₀ bc₁ is n = aux P bc₀ bc₁ is n n N.≤-refl

  private
    strong-induction/is : ∀ {P bc₀ bc₁ is n} →
      aux P bc₀ bc₁ is (suc n) ⌈ suc (suc n) /2⌉ (s≤s (N.≤-trans (N.⌈n/2⌉≤n n) N.≤-refl)) ≡
      strong-induction P bc₀ bc₁ is ⌈ suc (suc n) /2⌉
    strong-induction/is {P} {bc₀} {bc₁} {is} {n} = aux/unique
      where
        aux/unique : ∀ {m n₁ n₂ h₁ h₂} → aux P bc₀ bc₁ is n₁ m h₁ ≡ aux P bc₀ bc₁ is n₂ m h₂
        aux/unique {zero} = refl
        aux/unique {suc zero} = refl
        aux/unique {suc (suc m)} {h₁ = s≤s (s≤s h₁)} {h₂ = s≤s (s≤s h₂)} = Eq.cong (is m) aux/unique
    {-# REWRITE strong-induction/is #-}

  ⌈log₂_⌉ : ℕ → ℕ
  ⌈log₂_⌉ = strong-induction (λ _ → ℕ) zero zero (λ _ → suc)

  log₂-mono : ⌈log₂_⌉ Preserves Nat._≤_ ⟶ Nat._≤_
  log₂-mono {n₁} {n₂} =
    strong-induction (λ n₁ → ∀ n₂ → n₁ Nat.≤ n₂ → ⌈log₂ n₁ ⌉ Nat.≤ ⌈log₂ n₂ ⌉)
      (λ _ _ → z≤n)
      (λ _ _ → z≤n)
      (λ { n₁ ih (suc (suc n₂)) (s≤s (s≤s h)) → s≤s (ih ⌈ suc (suc n₂) /2⌉ (N.⌈n/2⌉-mono (s≤s (s≤s h))))})
      n₁
      n₂

  log₂-suc : ∀ n {k} → ⌈log₂ n ⌉ Nat.≤ suc k → ⌈log₂ ⌈ n /2⌉ ⌉ Nat.≤ k
  log₂-suc zero h = z≤n
  log₂-suc (suc zero) h = z≤n
  log₂-suc (suc (suc n)) (s≤s h) = h

  ⌈log₂n⌉≡0⇒n≤1 : {n : ℕ} → ⌈log₂ n ⌉ ≡ 0 → n Nat.≤ 1
  ⌈log₂n⌉≡0⇒n≤1 {zero} refl = z≤n
  ⌈log₂n⌉≡0⇒n≤1 {suc zero} refl = s≤s z≤n

module MergeSort (M : Comparable) where
  open Comparable M
  open Core M
  open Log2

  _≥_ : val A → val A → Set
  x ≥ y = y ≤ x

  _≰_ : val A → val A → Set
  x ≰ y = ¬ x ≤ y

  ≰⇒≥ : _≰_ ⇒ _≥_
  ≰⇒≥ {x} {y} h with ≤-total x y
  ... | inj₁ h₁ = ⊥-elim (h h₁)
  ... | inj₂ h₂ = h₂

  pair = Σ++ (list A) λ _ → (list A)

  split/clocked : cmp (Π (U (meta ℕ)) λ _ → Π (list A) λ _ → F pair)
  split/clocked zero    l        = ret ([] , l)
  split/clocked (suc k) []       = ret ([] , [])
  split/clocked (suc k) (x ∷ xs) = bind (F pair) (split/clocked k xs) λ (l₁ , l₂) → ret (x ∷ l₁ , l₂)

  split/clocked/correct : ∀ k k' l → k + k' ≡ length l →
    ◯ (∃ λ l₁ → ∃ λ l₂ → split/clocked k l ≡ ret (l₁ , l₂) × length l₁ ≡ k × length l₂ ≡ k' × l ↭ (l₁ ++ l₂))
  split/clocked/correct zero    k' l        refl u = [] , l , refl , refl , refl , refl
  split/clocked/correct (suc k) k' (x ∷ xs) h    u =
    let (l₁ , l₂ , ≡ , h₁ , h₂ , ↭) = split/clocked/correct k k' xs (N.suc-injective h) u in
    x ∷ l₁ , l₂ , Eq.cong (λ e → bind (F pair) e _) ≡ , Eq.cong suc h₁ , h₂ , prep x ↭

  split/clocked/length : ∀ k k' l → k + k' ≡ length l → (κ : ℕ → ℕ → α) →
    bind (meta α) (split/clocked k l) (λ (l₁ , l₂) → κ (length l₁) (length l₂)) ≡ κ k k'
  split/clocked/length zero    _  l        refl _ = refl
  split/clocked/length (suc k) k' (x ∷ xs) h    κ = split/clocked/length k k' xs (N.suc-injective h) (κ ∘ suc)

  split/clocked/cost : cmp (Π (U (meta ℕ)) λ _ → Π (list A) λ _ → cost)
  split/clocked/cost _ _ = 𝟘

  split/clocked≤split/clocked/cost : ∀ k l → ub pair (split/clocked k l) (split/clocked/cost k l)
  split/clocked≤split/clocked/cost zero    l        = ub/ret
  split/clocked≤split/clocked/cost (suc k) []       = ub/ret
  split/clocked≤split/clocked/cost (suc k) (x ∷ xs) = ub/bind/const 𝟘 𝟘 (split/clocked≤split/clocked/cost k xs) λ _ → ub/ret

  split : cmp (Π (list A) λ _ → F pair)
  split l = split/clocked ⌊ length l /2⌋ l

  split/correct : ∀ l →
    ◯ (∃ λ l₁ → ∃ λ l₂ → split l ≡ ret (l₁ , l₂) × length l₁ ≡ ⌊ length l /2⌋ × length l₂ ≡ ⌈ length l /2⌉ × l ↭ (l₁ ++ l₂))
  split/correct l = split/clocked/correct ⌊ length l /2⌋ ⌈ length l /2⌉ l (N.⌊n/2⌋+⌈n/2⌉≡n (length l))

  split/length : ∀ l (κ : ℕ → ℕ → α) →
    bind (meta α) (split l) (λ (l₁ , l₂) → κ (length l₁) (length l₂)) ≡ κ ⌊ length l /2⌋ ⌈ length l /2⌉
  split/length l = split/clocked/length ⌊ length l /2⌋ ⌈ length l /2⌉ l (N.⌊n/2⌋+⌈n/2⌉≡n (length l))

  split/cost : cmp (Π (list A) λ _ → cost)
  split/cost l = split/clocked/cost ⌊ length l /2⌋ l

  split≤split/cost : ∀ l → ub pair (split l) (split/cost l)
  split≤split/cost l = split/clocked≤split/clocked/cost ⌊ length l /2⌋ l

  merge/clocked : cmp (Π (U (meta ℕ)) λ _ → Π pair λ _ → F (list A))
  merge/clocked zero    (l₁     , l₂    ) = ret (l₁ ++ l₂)
  merge/clocked (suc k) ([]     , l₂    ) = ret l₂
  merge/clocked (suc k) (x ∷ xs , []    ) = ret (x ∷ xs)
  merge/clocked (suc k) (x ∷ xs , y ∷ ys) =
    bind (F (list A)) (x ≤ᵇ y)
      λ { false → bind (F (list A)) (merge/clocked k (x ∷ xs , ys)) (ret ∘ (y ∷_))
        ; true  → bind (F (list A)) (merge/clocked k (xs , y ∷ ys)) (ret ∘ (x ∷_)) }

  merge/clocked/correct : ∀ k l₁ l₂ → length l₁ + length l₂ Nat.≤ k → Sorted l₁ → Sorted l₂ →
    ◯ (∃ λ l → merge/clocked k (l₁ , l₂) ≡ ret l × SortedOf (l₁ ++ l₂) l)
  merge/clocked/correct zero    []       []       h       sorted₁        sorted₂        u =
    [] , refl , refl , []
  merge/clocked/correct (suc k) []       l₂       h       sorted₁        sorted₂        u =
    l₂ , refl , refl , sorted₂
  merge/clocked/correct (suc k) (x ∷ xs) []       h       sorted₁        sorted₂        u
    rewrite List.++-identityʳ (x ∷ xs) = x ∷ xs , refl , refl , sorted₁
  merge/clocked/correct (suc k) (x ∷ xs) (y ∷ ys) (s≤s h) (h₁ ∷ sorted₁) (h₂ ∷ sorted₂) u with h-cost x y
  merge/clocked/correct (suc k) (x ∷ xs) (y ∷ ys) (s≤s h) (h₁ ∷ sorted₁) (h₂ ∷ sorted₂) u | ub/intro {q = q} b _ h-eq rewrite eq/ref h-eq
    with ≤ᵇ-reflects-≤ u (Eq.trans (eq/ref h-eq) (step'/ext (F bool) (ret b) q u))
  merge/clocked/correct (suc k) (x ∷ xs) (y ∷ ys) (s≤s h) (h₁ ∷ sorted₁) (h₂ ∷ sorted₂) u | ub/intro {q = q} false _ h-eq | ofⁿ ¬p =
    let h = Eq.subst (Nat._≤ k) (N.+-suc (length xs) (length ys)) h in
    let (l , ≡ , ↭ , sorted) = merge/clocked/correct k (x ∷ xs) ys h (h₁ ∷ sorted₁) sorted₂ u in
    let p = ≰⇒≥ ¬p in
    y ∷ l , (
      let open ≡-Reasoning in
      begin
        step' (F (list A)) q (bind (F (list A)) (merge/clocked k (x ∷ xs , ys)) (ret ∘ (y ∷_)))
      ≡⟨ step'/ext (F (list A)) (bind (F (list A)) (merge/clocked k _) _) q u ⟩
        bind (F (list A)) (merge/clocked k (x ∷ xs , ys)) (ret ∘ (y ∷_))
      ≡⟨ Eq.cong (λ e → bind (F (list A)) e _) ≡ ⟩
        ret (y ∷ l)
      ∎
    ) , (
      let open PermutationReasoning in
      begin
        (x ∷ xs ++ y ∷ ys)
      ↭⟨ ++-comm (x ∷ xs) (y ∷ ys) ⟩
        (y ∷ ys ++ x ∷ xs)
      ≡⟨⟩
        y ∷ (ys ++ x ∷ xs)
      <⟨ ++-comm ys (x ∷ xs) ⟩
        y ∷ (x ∷ xs ++ ys)
      <⟨ ↭ ⟩
        y ∷ l
      ∎
     ) , All-resp-↭ (↭) (++⁺-All (p ∷ ≤-≤* p h₁) h₂) ∷ sorted
  merge/clocked/correct (suc k) (x ∷ xs) (y ∷ ys) (s≤s h) (h₁ ∷ sorted₁) (h₂ ∷ sorted₂) u | ub/intro {q = q} true  _ h-eq | ofʸ p =
    let (l , ≡ , ↭ , sorted) = merge/clocked/correct k xs (y ∷ ys) h sorted₁ (h₂ ∷ sorted₂) u in
    x ∷ l , (
      let open ≡-Reasoning in
      begin
        step' (F (list A)) q (bind (F (list A)) (merge/clocked k (xs , y ∷ ys)) (ret ∘ (x ∷_)))
      ≡⟨ step'/ext (F (list A)) (bind (F (list A)) (merge/clocked k _) _) q u ⟩
        bind (F (list A)) (merge/clocked k (xs , y ∷ ys)) (ret ∘ (x ∷_))
      ≡⟨ Eq.cong (λ e → bind (F (list A)) e _) ≡ ⟩
        ret (x ∷ l)
      ∎
    ) , prep x ↭ , All-resp-↭ (↭) (++⁺-All h₁ (p ∷ ≤-≤* p h₂)) ∷ sorted

  merge/clocked/length : ∀ k (l₁ l₂ : val (list A)) (κ : ℕ → α) →
    bind (meta α) (merge/clocked k (l₁ , l₂)) (κ ∘ length) ≡ κ (length l₁ + length l₂)
  merge/clocked/length zero    l₁       l₂       κ = Eq.cong κ (length-++ l₁)
  merge/clocked/length (suc k) []       l₂       κ = refl
  merge/clocked/length (suc k) (x ∷ xs) []       κ = Eq.cong (κ ∘ suc) (Eq.sym (N.+-identityʳ (length xs)))
  merge/clocked/length (suc k) (x ∷ xs) (y ∷ ys) κ with h-cost x y
  ... | ub/intro false _ h-eq rewrite eq/ref h-eq =
    begin
      bind _ (merge/clocked k (x ∷ xs , ys)) (λ l → (κ ∘ length) (y ∷ l))
    ≡⟨⟩
      bind _ (merge/clocked k (x ∷ xs , ys)) (λ l → (κ ∘ suc) (length l))
    ≡⟨ merge/clocked/length k (x ∷ xs) ys (κ ∘ suc) ⟩
      κ (suc (length (x ∷ xs) + length ys))
    ≡˘⟨ Eq.cong κ (N.+-suc (length (x ∷ xs)) (length ys)) ⟩
      κ (length (x ∷ xs) + length (y ∷ ys))
    ∎
      where open ≡-Reasoning
  ... | ub/intro true  _ h-eq rewrite eq/ref h-eq =
    begin
      bind _ (merge/clocked k (xs , y ∷ ys)) (λ l → (κ ∘ length) (x ∷ l))
    ≡⟨⟩
      bind _ (merge/clocked k (xs , y ∷ ys)) (λ l → (κ ∘ suc) (length l))
    ≡⟨ merge/clocked/length k xs (y ∷ ys) (κ ∘ suc) ⟩
      κ (suc (length xs + length (y ∷ ys)))
    ≡⟨⟩
      κ (length (x ∷ xs) + length (y ∷ ys))
    ∎
      where open ≡-Reasoning

  merge/clocked/cost : cmp (Π (U (meta ℕ)) λ _ → Π pair λ _ → cost)
  merge/clocked/cost k _ = k , k

  merge/clocked≤merge/clocked/cost : ∀ k p → ub (list A) (merge/clocked k p) (merge/clocked/cost k p)
  merge/clocked≤merge/clocked/cost zero    (l₁     , l₂    ) = ub/ret
  merge/clocked≤merge/clocked/cost (suc k) ([]     , l₂    ) = ub/relax (z≤n , z≤n) ub/ret
  merge/clocked≤merge/clocked/cost (suc k) (x ∷ xs , []    ) = ub/relax (z≤n , z≤n) ub/ret
  merge/clocked≤merge/clocked/cost (suc k) (x ∷ xs , y ∷ ys) =
    ub/bind/const (1 , 1) (k , k) (h-cost x y)
      λ { false → ub/bind/const' (k , k) 𝟘 (⊕-identityʳ _) (merge/clocked≤merge/clocked/cost k _) λ _ → ub/ret
        ; true  → ub/bind/const' (k , k) 𝟘 (⊕-identityʳ _) (merge/clocked≤merge/clocked/cost k _) λ _ → ub/ret }

  merge : cmp (Π pair λ _ → F (list A))
  merge (l₁ , l₂) = merge/clocked (length l₁ + length l₂) (l₁ , l₂)

  merge/correct : ∀ l₁ l₂ → Sorted l₁ → Sorted l₂ →
    ◯ (∃ λ l → merge (l₁ , l₂) ≡ ret l × SortedOf (l₁ ++ l₂) l)
  merge/correct l₁ l₂ = merge/clocked/correct (length l₁ + length l₂) l₁ l₂ N.≤-refl

  merge/length : ∀ l₁ l₂ (κ : ℕ → α) → bind (meta α) (merge (l₁ , l₂)) (κ ∘ length) ≡ κ (length l₁ + length l₂)
  merge/length l₁ l₂ = merge/clocked/length (length l₁ + length l₂) l₁ l₂

  merge/cost : cmp (Π pair λ _ → cost)
  merge/cost (l₁ , l₂) = merge/clocked/cost (length l₁ + length l₂) (l₁ , l₂)

  merge≤merge/cost : ∀ p → ub (list A) (merge p) (merge/cost p)
  merge≤merge/cost (l₁ , l₂) = merge/clocked≤merge/clocked/cost (length l₁ + length l₂) (l₁ , l₂)

  sort/clocked : cmp (Π (U (meta ℕ)) λ _ → Π (list A) λ _ → F (list A))
  sort/clocked zero    l = ret l
  sort/clocked (suc k) l =
    bind (F (list A)) (split l) λ (l₁ , l₂) →
      bind (F (list A)) (sort/clocked k l₁ & sort/clocked k l₂) merge

  sort/clocked/correct : ∀ k l → ⌈log₂ length l ⌉ Nat.≤ k → SortResult (sort/clocked k) l
  sort/clocked/correct zero    l h u = l , refl , refl , short-sorted (⌈log₂n⌉≡0⇒n≤1 (N.n≤0⇒n≡0 h))
  sort/clocked/correct (suc k) l h u =
    let (l₁ , l₂ , ≡ , length₁ , length₂ , ↭) = split/correct l u in
    let (l₁' , ≡₁ , ↭₁ , sorted₁) = sort/clocked/correct k l₁ (
                                      let open ≤-Reasoning in
                                      begin
                                        ⌈log₂ length l₁ ⌉
                                      ≡⟨ Eq.cong ⌈log₂_⌉ length₁ ⟩
                                        ⌈log₂ ⌊ length l /2⌋ ⌉
                                      ≤⟨ log₂-mono (N.⌊n/2⌋≤⌈n/2⌉ (length l)) ⟩
                                        ⌈log₂ ⌈ length l /2⌉ ⌉
                                      ≤⟨ log₂-suc (length l) h ⟩
                                        k
                                      ∎
                                    ) u in
    let (l₂' , ≡₂ , ↭₂ , sorted₂) = sort/clocked/correct k l₂ (
                                      let open ≤-Reasoning in
                                      begin
                                        ⌈log₂ length l₂ ⌉
                                      ≡⟨ Eq.cong ⌈log₂_⌉ length₂ ⟩
                                        ⌈log₂ ⌈ length l /2⌉ ⌉
                                      ≤⟨ log₂-suc (length l) h ⟩
                                        k
                                      ∎
                                    ) u in
    let (l' , ≡' , ↭' , sorted) = merge/correct l₁' l₂' sorted₁ sorted₂ u in
    l' , (
      let open ≡-Reasoning in
      begin
        sort/clocked (suc k) l
      ≡⟨⟩
        (bind (F (list A)) (split l) λ (l₁ , l₂) →
          bind (F (list A)) (sort/clocked k l₁ & sort/clocked k l₂) merge)
      ≡⟨ Eq.cong (λ e → bind (F (list A)) e _) ≡ ⟩
        bind (F (list A)) (sort/clocked k l₁ & sort/clocked k l₂) merge
      ≡⟨ Eq.cong (λ e → bind (F (list A)) e merge) (Eq.cong₂ _&_ ≡₁ ≡₂) ⟩
        bind (F (list A)) (ret l₁' & ret l₂') merge
      ≡⟨ bind/par 𝟘 𝟘 ⟩
        merge (l₁' , l₂')
      ≡⟨ ≡' ⟩
        ret l'
      ∎
    ) , (
      let open PermutationReasoning in
      begin
        l
      ↭⟨ ↭ ⟩
        l₁ ++ l₂
      ↭⟨ ++⁺-↭ ↭₁ ↭₂ ⟩
        l₁' ++ l₂'
      ↭⟨ ↭' ⟩
        l'
      ∎
    ) , sorted

  sort/clocked/length : ∀ k l (κ : ℕ → α) → bind (meta α) (sort/clocked k l) (κ ∘ length) ≡ κ (length l)
  sort/clocked/length {_} zero    l κ = refl
  sort/clocked/length {α} (suc k) l κ =
    begin
      bnd (sort/clocked (suc k) l) (κ ∘ length)
    ≡⟨⟩
      (bnd (split l) λ (l₁ , l₂) →
        bnd (sort/clocked k l₁ & sort/clocked k l₂) λ (l₁' , l₂') →
          bnd (merge (l₁' , l₂')) (κ ∘ length))
    ≡⟨
      Eq.cong (bnd (split l)) (funext λ (l₁ , l₂) →
        Eq.cong (bnd (sort/clocked k l₁ & sort/clocked k l₂)) (funext λ (l₁' , l₂') →
          merge/length l₁' l₂' κ
        )
      )
    ⟩
      (bnd (split l) λ (l₁ , l₂) →
        bnd (sort/clocked k l₁ & sort/clocked k l₂) λ (l₁' , l₂') →
          κ (length l₁' + length l₂'))
    ≡⟨
      Eq.cong (bnd (split l)) (funext λ (l₁ , l₂) →
        {!   !}
      )
    ⟩
      (bnd (split l) λ (l₁ , l₂) →
        κ (length l₁ + length l₂))
    ≡⟨ split/length l (λ n₁ n₂ → κ (n₁ + n₂)) ⟩
      κ (⌊ length l /2⌋ + ⌈ length l /2⌉ )
    ≡⟨ Eq.cong κ (N.⌊n/2⌋+⌈n/2⌉≡n (length l)) ⟩
      κ (length l)
    ∎
    where
      open ≡-Reasoning

      bnd : ∀ {A} → cmp (F A) → (val A → α) → α
      bnd = bind (meta α)

  sort/clocked/cost : cmp (Π (U (meta ℕ)) λ _ → Π (list A) λ _ → cost)
  sort/clocked/cost zero    l = 𝟘
  sort/clocked/cost (suc k) l =
    bind cost (split l) λ (l₁ , l₂) → split/cost l ⊕
      bind cost (sort/clocked k l₁ & sort/clocked k l₂) λ (l₁' , l₂') → (sort/clocked/cost k l₁ ⊗ sort/clocked/cost k l₂) ⊕
        merge/cost (l₁' , l₂')

  sort/clocked/cost/closed : cmp (Π (U (meta ℕ)) λ _ → Π (list A) λ _ → cost)
  sort/clocked/cost/closed k l = k * length l , 2 * length l + k

  sort/clocked/cost≤sort/clocked/cost/closed : ∀ k l → sort/clocked/cost k l P≤ sort/clocked/cost/closed k l
  sort/clocked/cost≤sort/clocked/cost/closed zero    l = z≤n , z≤n
  sort/clocked/cost≤sort/clocked/cost/closed (suc k) l =
    let open P≤-Reasoning in
    begin
      sort/clocked/cost (suc k) l
    ≡⟨⟩
      (bind cost (split l) λ (l₁ , l₂) → split/cost l ⊕
        bind cost (sort/clocked k l₁ & sort/clocked k l₂) λ (l₁' , l₂') → (sort/clocked/cost k l₁ ⊗ sort/clocked/cost k l₂) ⊕
          merge/cost (l₁' , l₂'))
    ≡⟨⟩
      (bind cost (split l) λ (l₁ , l₂) → split/cost l ⊕
        bind cost (sort/clocked k l₁ & sort/clocked k l₂) λ (l₁' , l₂') → (sort/clocked/cost k l₁ ⊗ sort/clocked/cost k l₂) ⊕
          (length l₁' + length l₂' , length l₁' + length l₂'))
    ≡⟨ {!   !} ⟩
      (bind cost (split l) λ (l₁ , l₂) → split/cost l ⊕
        ((sort/clocked/cost k l₁ ⊗ sort/clocked/cost k l₂) ⊕
          (length l₁ + length l₂ , length l₁ + length l₂)))
    ≤⟨ {!   !} ⟩
      (bind cost (split l) λ (l₁ , l₂) → split/cost l ⊕
        ((sort/clocked/cost/closed k l₁ ⊗ sort/clocked/cost/closed k l₂) ⊕
          (length l₁ + length l₂ , length l₁ + length l₂)))
    ≡⟨⟩
      (bind cost (split l) λ (l₁ , l₂) → split/cost l ⊕
        (((k * length l₁ , 2 * length l₁ + k) ⊗ (k * length l₂ , 2 * length l₂ + k)) ⊕
          (length l₁ + length l₂ , length l₁ + length l₂)))
    ≡⟨ split/length l (λ n₁ n₂ → ((k * n₁ , 2 * n₁ + k) ⊗ (k * n₂ , 2 * n₂ + k)) ⊕ (n₁ + n₂ , n₁ + n₂)) ⟩
      (split/cost l ⊕
        ((k * ⌊ length l /2⌋ , 2 * ⌊ length l /2⌋ + k) ⊗ (k * ⌈ length l /2⌉ , 2 * ⌈ length l /2⌉ + k)) ⊕
          (⌊ length l /2⌋ + ⌈ length l /2⌉ , ⌊ length l /2⌋ + ⌈ length l /2⌉))
    ≡⟨ ⊕-identityˡ _ ⟩
      ((k * ⌊ length l /2⌋ , 2 * ⌊ length l /2⌋ + k) ⊗ (k * ⌈ length l /2⌉ , 2 * ⌈ length l /2⌉ + k)) ⊕
        (⌊ length l /2⌋ + ⌈ length l /2⌉ , ⌊ length l /2⌋ + ⌈ length l /2⌉)
    ≡⟨
      Eq.cong (((k * ⌊ length l /2⌋ , 2 * ⌊ length l /2⌋ + k) ⊗ (k * ⌈ length l /2⌉ , 2 * ⌈ length l /2⌉ + k)) ⊕_) (
        Eq.cong₂ _,_ (N.⌊n/2⌋+⌈n/2⌉≡n (length l)) (N.⌊n/2⌋+⌈n/2⌉≡n (length l))
      )
    ⟩
      ((k * ⌊ length l /2⌋ , 2 * ⌊ length l /2⌋ + k) ⊗ (k * ⌈ length l /2⌉ , 2 * ⌈ length l /2⌉ + k)) ⊕
        (length l , length l)
    ≤⟨ arithmetic/work (length l) , arithmetic/span (length l) ⟩
      suc k * length l , 2 * length l + suc k
    ≡⟨⟩
      sort/clocked/cost/closed (suc k) l
    ∎
      where
        arithmetic/work : ∀ n → k * ⌊ n /2⌋ + k * ⌈ n /2⌉ + n Nat.≤ suc k * n
        arithmetic/work n =
          begin
            k * ⌊ n /2⌋ + k * ⌈ n /2⌉ + n
          ≡⟨ N.+-comm _ n ⟩
            n + (k * ⌊ n /2⌋ + k * ⌈ n /2⌉)
          ≡˘⟨ Eq.cong₂ (_+_) (N.*-identityˡ _) (N.*-distribˡ-+ k _ _) ⟩
            1 * n + k * (⌊ n /2⌋ + ⌈ n /2⌉)
          ≡⟨ Eq.cong (λ m → 1 * n + k * m) (N.⌊n/2⌋+⌈n/2⌉≡n n) ⟩
            1 * n + k * n
          ≡˘⟨ N.*-distribʳ-+ _ 1 k ⟩
            suc k * n
          ∎
            where open ≤-Reasoning

        lemma/2n≡n+n : ∀ n → 2 * n ≡ n + n
        lemma/2n≡n+n n = Eq.cong (λ m → n + m) (N.+-identityʳ n)

        arithmetic/span : ∀ n → (2 * ⌊ n /2⌋ + k) ⊔ (2 * ⌈ n /2⌉ + k) + n Nat.≤ 2 * n + suc k
        arithmetic/span n =
          begin
            (2 * ⌊ n /2⌋ + k) ⊔ (2 * ⌈ n /2⌉ + k) + n
          ≤⟨ N.+-monoˡ-≤ n (N.⊔-monoˡ-≤ (2 * ⌈ n /2⌉ + k) (N.+-monoˡ-≤ k (N.*-monoʳ-≤ 2 (N.⌊n/2⌋≤⌈n/2⌉ n)))) ⟩
            (2 * ⌈ n /2⌉ + k) ⊔ (2 * ⌈ n /2⌉ + k) + n
          ≡⟨ Eq.cong (_+ n) (N.⊔-idem _) ⟩
            2 * ⌈ n /2⌉ + k + n
          ≡⟨ N.+-assoc (2 * ⌈ n /2⌉) k n ⟩
            2 * ⌈ n /2⌉ + (k + n)
          ≡⟨ Eq.cong (_+ (k + n)) (lemma/2n≡n+n ⌈ n /2⌉) ⟩
            (⌈ n /2⌉ + ⌈ n /2⌉) + (k + n)
          ≡⟨⟩
            (⌊ suc n /2⌋ + ⌈ n /2⌉) + (k + n)
          ≤⟨ N.+-monoˡ-≤ (k + n) (N.+-monoʳ-≤ ⌊ suc n /2⌋ (N.⌈n/2⌉-mono (N.n≤1+n n))) ⟩
            (⌊ suc n /2⌋ + ⌈ suc n /2⌉) + (k + n)
          ≡⟨ Eq.cong (_+ (k + n)) (N.⌊n/2⌋+⌈n/2⌉≡n (suc n)) ⟩
            suc n + (k + n)
          ≡⟨⟩
            suc (n + (k + n))
          ≡⟨ Eq.cong (λ m → suc (n + m)) (N.+-comm k n) ⟩
            suc (n + (n + k))
          ≡˘⟨ Eq.cong suc (N.+-assoc n n k) ⟩
            suc ((n + n) + k)
          ≡˘⟨ N.+-suc (n + n) k ⟩
            (n + n) + suc k
          ≡˘⟨ Eq.cong (_+ suc k) (lemma/2n≡n+n n) ⟩
            2 * n + suc k
          ∎
            where open ≤-Reasoning

  sort/clocked≤sort/clocked/cost : ∀ k l → ub (list A) (sort/clocked k l) (sort/clocked/cost k l)
  sort/clocked≤sort/clocked/cost zero l = ub/ret
  sort/clocked≤sort/clocked/cost (suc k) l =
    ub/bind _ _ (split≤split/cost l) λ (l₁ , l₂) →
      ub/bind _ _ (ub/par (sort/clocked≤sort/clocked/cost k l₁) (sort/clocked≤sort/clocked/cost k l₂)) λ (l₁' , l₂') →
        merge≤merge/cost (l₁' , l₂')

  sort/clocked≤sort/clocked/cost/closed : ∀ k l → ub (list A) (sort/clocked k l) (sort/clocked/cost/closed k l)
  sort/clocked≤sort/clocked/cost/closed k l = ub/relax (sort/clocked/cost≤sort/clocked/cost/closed k l) (sort/clocked≤sort/clocked/cost k l)

  sort/depth : cmp (Π (list A) λ _ → meta ℕ)
  sort/depth l = ⌈log₂ length l ⌉

  sort : cmp (Π (list A) λ _ → F (list A))
  sort l = sort/clocked (sort/depth l) l

  sort/correct : IsSort sort
  sort/correct l = sort/clocked/correct (sort/depth l) l N.≤-refl

  sort/cost : cmp (Π (list A) λ _ → cost)
  sort/cost l = sort/clocked/cost (sort/depth l) l

  sort/cost/closed : cmp (Π (list A) λ _ → cost)
  sort/cost/closed l = sort/clocked/cost/closed (sort/depth l) l

  sort≤sort/cost : ∀ l → ub (list A) (sort l) (sort/cost l)
  sort≤sort/cost l = sort/clocked≤sort/clocked/cost (sort/depth l) l

  sort≤sort/cost/closed : ∀ l → ub (list A) (sort l) (sort/cost/closed l)
  sort≤sort/cost/closed l = sort/clocked≤sort/clocked/cost/closed (sort/depth l) l

module Ex/MergeSort where
  module Sort = MergeSort NatComparable

  list' = list (U (meta ℕ))

  ex/split : cmp (F Sort.pair)
  ex/split = Sort.split (6 ∷ 2 ∷ 8 ∷ 3 ∷ 1 ∷ 8 ∷ 5 ∷ [])

  ex/merge : cmp (F list')
  ex/merge = Sort.merge (2 ∷ 3 ∷ 6 ∷ 8 ∷ [] , 1 ∷ 5 ∷ 8 ∷ [])

  ex/sort : cmp (F list')
  ex/sort = Sort.sort (1 ∷ 5 ∷ 3 ∷ 1 ∷ 2 ∷ [])

  ex/sort/forward : cmp (F list')
  ex/sort/forward = Sort.sort test/forward  -- cost: ?

  ex/sort/backward : cmp (F list')
  ex/sort/backward = Sort.sort test/backward  -- cost: ?

  ex/sort/shuffled : cmp (F list')
  ex/sort/shuffled = Sort.sort test/shuffled  -- cost: ?

module MergeSortFast (M : Comparable) where
  open Comparable M
  open Core M
  open Log2

  _≥_ : val A → val A → Set
  x ≥ y = y ≤ x

  _≰_ : val A → val A → Set
  x ≰ y = ¬ x ≤ y

  ≰⇒≥ : _≰_ ⇒ _≥_
  ≰⇒≥ {x} {y} h with ≤-total x y
  ... | inj₁ h₁ = ⊥-elim (h h₁)
  ... | inj₂ h₂ = h₂

  pair = Σ++ (list A) λ _ → (list A)

  split/clocked : cmp (Π (U (meta ℕ)) λ _ → Π (list A) λ _ → F pair)
  split/clocked zero    l        = ret ([] , l)
  split/clocked (suc k) []       = ret ([] , [])
  split/clocked (suc k) (x ∷ xs) = bind (F pair) (split/clocked k xs) λ (l₁ , l₂) → ret (x ∷ l₁ , l₂)

  split/clocked/correct : ∀ k k' l → k + k' ≡ length l →
    ◯ (∃ λ l₁ → ∃ λ l₂ → split/clocked k l ≡ ret (l₁ , l₂) × length l₁ ≡ k × length l₂ ≡ k' × l ↭ (l₁ ++ l₂))
  split/clocked/correct zero    k' l        refl u = [] , l , refl , refl , refl , refl
  split/clocked/correct (suc k) k' (x ∷ xs) h    u =
    let (l₁ , l₂ , ≡ , h₁ , h₂ , ↭) = split/clocked/correct k k' xs (N.suc-injective h) u in
    x ∷ l₁ , l₂ , Eq.cong (λ e → bind (F pair) e _) ≡ , Eq.cong suc h₁ , h₂ , prep x ↭

  split/clocked/length : ∀ k k' l → k + k' ≡ length l → (κ : ℕ → ℕ → α) →
    bind (meta α) (split/clocked k l) (λ (l₁ , l₂) → κ (length l₁) (length l₂)) ≡ κ k k'
  split/clocked/length zero    _  l        refl _ = refl
  split/clocked/length (suc k) k' (x ∷ xs) h    κ = split/clocked/length k k' xs (N.suc-injective h) (κ ∘ suc)

  split/clocked/cost : cmp (Π (U (meta ℕ)) λ _ → Π (list A) λ _ → cost)
  split/clocked/cost _ _ = 𝟘

  split/clocked≤split/clocked/cost : ∀ k l → ub pair (split/clocked k l) (split/clocked/cost k l)
  split/clocked≤split/clocked/cost zero    l        = ub/ret
  split/clocked≤split/clocked/cost (suc k) []       = ub/ret
  split/clocked≤split/clocked/cost (suc k) (x ∷ xs) = ub/bind/const 𝟘 𝟘 (split/clocked≤split/clocked/cost k xs) λ _ → ub/ret

  split : cmp (Π (list A) λ _ → F pair)
  split l = split/clocked ⌊ length l /2⌋ l

  split/correct : ∀ l →
    ◯ (∃ λ l₁ → ∃ λ l₂ → split l ≡ ret (l₁ , l₂) × length l₁ ≡ ⌊ length l /2⌋ × length l₂ ≡ ⌈ length l /2⌉ × l ↭ (l₁ ++ l₂))
  split/correct l = split/clocked/correct ⌊ length l /2⌋ ⌈ length l /2⌉ l (N.⌊n/2⌋+⌈n/2⌉≡n (length l))

  split/length : ∀ l (κ : ℕ → ℕ → α) →
    bind (meta α) (split l) (λ (l₁ , l₂) → κ (length l₁) (length l₂)) ≡ κ ⌊ length l /2⌋ ⌈ length l /2⌉
  split/length l = split/clocked/length ⌊ length l /2⌋ ⌈ length l /2⌉ l (N.⌊n/2⌋+⌈n/2⌉≡n (length l))

  split/cost : cmp (Π (list A) λ _ → cost)
  split/cost l = split/clocked/cost ⌊ length l /2⌋ l

  split≤split/cost : ∀ l → ub pair (split l) (split/cost l)
  split≤split/cost l = split/clocked≤split/clocked/cost ⌊ length l /2⌋ l

  triple = Σ++ (list A) λ _ → Σ++ A λ _ → (list A)

  splitMid/clocked : cmp (Π (U (meta ℕ)) λ k → Π (list A) λ l → Π (U (meta (k Nat.< length l))) λ _ → F triple)
  splitMid/clocked zero    (x ∷ xs) (s≤s _) = ret ([] , x , xs)
  splitMid/clocked (suc k) (x ∷ xs) (s≤s h) =
    bind (F triple) (splitMid/clocked k xs h) λ (l₁ , y , l₂) → ret ((x ∷ l₁) , y , l₂)

  -- splitMid/clocked/correct : ∀ k k' l → k + k' ≡ length l →
  --   ◯ (∃ λ l₁ → ∃ λ l₂ → splitMid/clocked k l ≡ ret (l₁ , l₂) × length l₁ ≡ k × length l₂ ≡ k' × l ↭ (l₁ ++ l₂))
  -- splitMid/clocked/correct zero    k' l        refl u = [] , l , refl , refl , refl , refl
  -- splitMid/clocked/correct (suc k) k' (x ∷ xs) h    u =
  --   let (l₁ , l₂ , ≡ , h₁ , h₂ , ↭) = splitMid/clocked/correct k k' xs (N.suc-injective h) u in
  --   x ∷ l₁ , l₂ , Eq.cong (λ e → bind (F pair) e _) ≡ , Eq.cong suc h₁ , h₂ , prep x ↭

  -- splitMid/clocked/length : ∀ k k' l → k + k' ≡ length l → (κ : ℕ → ℕ → α) →
  --   bind (meta α) (splitMid/clocked k l) (λ (l₁ , l₂) → κ (length l₁) (length l₂)) ≡ κ k k'
  -- splitMid/clocked/length zero    _  l        refl _ = refl
  -- splitMid/clocked/length (suc k) k' (x ∷ xs) h    κ = splitMid/clocked/length k k' xs (N.suc-injective h) (κ ∘ suc)

  splitMid/clocked/cost : cmp (Π (U (meta ℕ)) λ k → Π (list A) λ l → Π (U (meta (k Nat.< length l))) λ _ → cost)
  splitMid/clocked/cost _ _ _ = 𝟘

  splitMid/clocked≤splitMid/clocked/cost : ∀ k l h → ub triple (splitMid/clocked k l h) (splitMid/clocked/cost k l h)
  splitMid/clocked≤splitMid/clocked/cost zero    (x ∷ xs) (s≤s h) = ub/ret
  splitMid/clocked≤splitMid/clocked/cost (suc k) (x ∷ xs) (s≤s h) =
    ub/bind/const 𝟘 𝟘 (splitMid/clocked≤splitMid/clocked/cost k xs h) λ _ → ub/ret

  splitMid : cmp (Π (list A) λ l → Π (U (meta (0 Nat.< length l))) λ _ → F triple)
  splitMid (x ∷ xs) (s≤s h) = splitMid/clocked ⌊ length (x ∷ xs) /2⌋ (x ∷ xs) (s≤s (N.⌈n/2⌉≤n _))

  -- splitMid/correct : ∀ l →
  --   ◯ (∃ λ l₁ → ∃ λ l₂ → splitMid l ≡ ret (l₁ , l₂) × length l₁ ≡ ⌊ length l /2⌋ × length l₂ ≡ ⌈ length l /2⌉ × l ↭ (l₁ ++ l₂))
  -- splitMid/correct l = splitMid/clocked/correct ⌊ length l /2⌋ ⌈ length l /2⌉ l (N.⌊n/2⌋+⌈n/2⌉≡n (length l))

  -- splitMid/length : ∀ l (κ : ℕ → ℕ → α) →
  --   bind (meta α) (splitMid l) (λ (l₁ , l₂) → κ (length l₁) (length l₂)) ≡ κ ⌊ length l /2⌋ ⌈ length l /2⌉
  -- splitMid/length l = splitMid/clocked/length ⌊ length l /2⌋ ⌈ length l /2⌉ l (N.⌊n/2⌋+⌈n/2⌉≡n (length l))

  splitMid/cost : cmp (Π (list A) λ l → Π (U (meta (0 Nat.< length l))) λ _ → cost)
  splitMid/cost (x ∷ xs) (s≤s h) = splitMid/clocked/cost ⌊ length (x ∷ xs) /2⌋ (x ∷ xs) (s≤s (N.⌈n/2⌉≤n _))

  splitMid≤splitMid/cost : ∀ l h → ub triple (splitMid l h) (splitMid/cost l h)
  splitMid≤splitMid/cost (x ∷ xs) (s≤s h) = splitMid/clocked≤splitMid/clocked/cost ⌊ length (x ∷ xs) /2⌋ (x ∷ xs) (s≤s (N.⌈n/2⌉≤n _))

  splitBy/clocked : cmp (Π (U (meta ℕ)) λ _ → Π (list A) λ _ → Π A λ _ → F pair)
  splitBy/clocked zero    l        pivot = ret ([] , l)
  splitBy/clocked (suc k) []       pivot = ret ([] , [])
  splitBy/clocked (suc k) (x ∷ xs) pivot =
    bind (F pair) (splitMid (x ∷ xs) (s≤s z≤n)) λ (l₁ , mid , l₂) →
      bind (F pair) (mid ≤ᵇ pivot) λ b →
        case b of
          λ { false → bind (F pair) (splitBy/clocked k l₁ pivot) λ (l₁₁ , l₁₂) → ret (l₁₁ , l₁₂ ++ mid ∷ l₂)
            ; true  → bind (F pair) (splitBy/clocked k l₂ pivot) λ (l₂₁ , l₂₂) → ret (l₁ ++ mid ∷ l₂₁ , l₂₂) }

  -- splitBy/clocked/correct : ∀ k k' l → k + k' ≡ length l →
  --   ◯ (∃ λ l₁ → ∃ λ l₂ → splitBy/clocked k l ≡ ret (l₁ , l₂) × length l₁ ≡ k × length l₂ ≡ k' × l ↭ (l₁ ++ l₂))
  -- splitBy/clocked/correct zero    k' l        refl u = [] , l , refl , refl , refl , refl
  -- splitBy/clocked/correct (suc k) k' (x ∷ xs) h    u =
  --   let (l₁ , l₂ , ≡ , h₁ , h₂ , ↭) = splitBy/clocked/correct k k' xs (N.suc-injective h) u in
  --   x ∷ l₁ , l₂ , Eq.cong (λ e → bind (F pair) e _) ≡ , Eq.cong suc h₁ , h₂ , prep x ↭

  -- splitBy/clocked/length : ∀ k k' l → k + k' ≡ length l → (κ : ℕ → ℕ → α) →
  --   bind (meta α) (splitBy/clocked k l) (λ (l₁ , l₂) → κ (length l₁) (length l₂)) ≡ κ k k'
  -- splitBy/clocked/length zero    _  l        refl _ = refl
  -- splitBy/clocked/length (suc k) k' (x ∷ xs) h    κ = splitBy/clocked/length k k' xs (N.suc-injective h) (κ ∘ suc)

  splitBy/clocked/cost : cmp (Π (U (meta ℕ)) λ _ → Π (list A) λ _ → Π A λ _ → cost)
  splitBy/clocked/cost zero    l        pivot = 𝟘
  splitBy/clocked/cost (suc k) []       pivot = 𝟘
  splitBy/clocked/cost (suc k) (x ∷ xs) pivot =
    bind cost (splitMid (x ∷ xs) (s≤s z≤n)) λ (l₁ , mid , l₂) → splitMid/cost (x ∷ xs) (s≤s z≤n) ⊕
      bind cost (mid ≤ᵇ pivot) λ b → (1 , 1) ⊕
        (case b of
          λ { false → bind cost (splitBy/clocked k l₁ pivot) λ (l₁₁ , l₁₂) → splitBy/clocked/cost k l₁ pivot ⊕ 𝟘
            ; true  → bind cost (splitBy/clocked k l₂ pivot) λ (l₂₁ , l₂₂) → splitBy/clocked/cost k l₂ pivot ⊕ 𝟘 })

  splitBy/clocked/cost/closed : cmp (Π (U (meta ℕ)) λ _ → Π (list A) λ _ → Π A λ _ → cost)
  splitBy/clocked/cost/closed k _ _ = k , k

  splitBy/clocked/cost≤splitBy/clocked/cost/closed : ∀ k l pivot → splitBy/clocked/cost k l pivot P≤ splitBy/clocked/cost/closed k l pivot
  splitBy/clocked/cost≤splitBy/clocked/cost/closed k l pivot = {!   !}

  splitBy/clocked≤splitBy/clocked/cost : ∀ k l pivot → ub pair (splitBy/clocked k l pivot) (splitBy/clocked/cost k l pivot)
  splitBy/clocked≤splitBy/clocked/cost zero    l        pivot = ub/ret
  splitBy/clocked≤splitBy/clocked/cost (suc k) []       pivot = ub/ret
  splitBy/clocked≤splitBy/clocked/cost (suc k) (x ∷ xs) pivot =
    ub/bind {e = splitMid (x ∷ xs) (s≤s z≤n)} (splitMid/cost (x ∷ xs) (s≤s z≤n)) _ (splitMid≤splitMid/cost (x ∷ xs) (s≤s z≤n)) λ (l₁ , mid , l₂) →
      ub/bind (1 , 1) _ (h-cost mid pivot)
        λ { false → ub/bind (splitBy/clocked/cost k l₁ pivot) (λ _ → 𝟘) (splitBy/clocked≤splitBy/clocked/cost k l₁ pivot) λ _ → ub/ret
          ; true  → ub/bind (splitBy/clocked/cost k l₂ pivot) (λ _ → 𝟘) (splitBy/clocked≤splitBy/clocked/cost k l₂ pivot) λ _ → ub/ret }

  splitBy/clocked≤splitBy/clocked/cost/closed : ∀ k l pivot → ub pair (splitBy/clocked k l pivot) (splitBy/clocked/cost/closed k l pivot)
  splitBy/clocked≤splitBy/clocked/cost/closed k l pivot = ub/relax (splitBy/clocked/cost≤splitBy/clocked/cost/closed k l pivot) (splitBy/clocked≤splitBy/clocked/cost k l pivot)

  -- splitBy/clocked≤splitBy/clocked/cost : ∀ k l → ub pair (splitBy/clocked k l) (splitBy/clocked/cost k l)
  -- splitBy/clocked≤splitBy/clocked/cost zero    l        = ub/ret
  -- splitBy/clocked≤splitBy/clocked/cost (suc k) []       = ub/ret
  -- splitBy/clocked≤splitBy/clocked/cost (suc k) (x ∷ xs) = ub/bind/const 𝟘 𝟘 (splitBy/clocked≤splitBy/clocked/cost k xs) λ _ → ub/ret

  splitBy : cmp (Π (list A) λ _ → Π A λ _ → F pair)
  splitBy l pivot = splitBy/clocked ⌈log₂ length l ⌉ l pivot

  -- splitBy/correct : ∀ l →
  --   ◯ (∃ λ l₁ → ∃ λ l₂ → splitBy l ≡ ret (l₁ , l₂) × length l₁ ≡ ⌊ length l /2⌋ × length l₂ ≡ ⌈ length l /2⌉ × l ↭ (l₁ ++ l₂))
  -- splitBy/correct l = splitBy/clocked/correct ⌊ length l /2⌋ ⌈ length l /2⌉ l (N.⌊n/2⌋+⌈n/2⌉≡n (length l))

  -- splitBy/length : ∀ l (κ : ℕ → ℕ → α) →
  --   bind (meta α) (splitBy l) (λ (l₁ , l₂) → κ (length l₁) (length l₂)) ≡ κ ⌊ length l /2⌋ ⌈ length l /2⌉
  -- splitBy/length l = splitBy/clocked/length ⌊ length l /2⌋ ⌈ length l /2⌉ l (N.⌊n/2⌋+⌈n/2⌉≡n (length l))

  splitBy/cost : cmp (Π (list A) λ _ → Π A λ _ → cost)
  splitBy/cost l = splitBy/clocked/cost ⌈log₂ length l ⌉ l

  splitBy/cost/closed : cmp (Π (list A) λ _ → Π A λ _ → cost)
  splitBy/cost/closed l = splitBy/clocked/cost/closed ⌈log₂ length l ⌉ l

  splitBy≤splitBy/cost : ∀ l pivot → ub pair (splitBy l pivot) (splitBy/cost l pivot)
  splitBy≤splitBy/cost l pivot = splitBy/clocked≤splitBy/clocked/cost ⌈log₂ length l ⌉ l pivot

  splitBy≤splitBy/cost/closed : ∀ l pivot → ub pair (splitBy l pivot) (splitBy/cost/closed l pivot)
  splitBy≤splitBy/cost/closed l pivot = splitBy/clocked≤splitBy/clocked/cost/closed ⌈log₂ length l ⌉ l pivot

  minmax : val (list A) × val (list A) → val (list A) × val (list A)
  minmax (l₁ , l₂) with length l₁ Nat.≤ᵇ length l₂
  ... | false = l₂ , l₁
  ... | true  = l₁ , l₂

  merge/clocked : cmp (Π (U (meta ℕ)) λ _ → Π pair λ _ → F (list A))
  merge/clocked zero    (l₁ , l₂) = ret (l₁ ++ l₂)
  merge/clocked (suc k) (l₁ , l₂) with minmax (l₁ , l₂)
  merge/clocked (suc k) _ | []     , l₂      = ret l₂
  merge/clocked (suc k) _ | x ∷ l₁ , l₂ =
    bind (F (list A)) (splitMid (x ∷ l₁) (s≤s z≤n)) λ (l₁₁ , pivot , l₁₂) →
      bind (F (list A)) (splitBy l₂ pivot) λ (l₂₁ , l₂₂) →
        bind (F (list A)) (merge/clocked k (l₁₁ , l₂₁) & merge/clocked k (l₁₂ , l₂₂)) λ (l₁' , l₂') →
          ret (l₁' ++ pivot ∷ l₂')

  -- merge/clocked/correct : ∀ k l₁ l₂ → length l₁ + length l₂ Nat.≤ k → Sorted l₁ → Sorted l₂ →
  --   ◯ (∃ λ l → merge/clocked k (l₁ , l₂) ≡ ret l × SortedOf (l₁ ++ l₂) l)
  -- merge/clocked/correct zero    []       []       h       sorted₁        sorted₂        u =
  --   [] , refl , refl , []
  -- merge/clocked/correct (suc k) []       l₂       h       sorted₁        sorted₂        u =
  --   l₂ , refl , refl , sorted₂
  -- merge/clocked/correct (suc k) (x ∷ xs) []       h       sorted₁        sorted₂        u
  --   rewrite List.++-identityʳ (x ∷ xs) = x ∷ xs , refl , refl , sorted₁
  -- merge/clocked/correct (suc k) (x ∷ xs) (y ∷ ys) (s≤s h) (h₁ ∷ sorted₁) (h₂ ∷ sorted₂) u with h-cost x y
  -- merge/clocked/correct (suc k) (x ∷ xs) (y ∷ ys) (s≤s h) (h₁ ∷ sorted₁) (h₂ ∷ sorted₂) u | ub/intro {q = q} b _ h-eq rewrite eq/ref h-eq
  --   with ≤ᵇ-reflects-≤ u (Eq.trans (eq/ref h-eq) (step'/ext (F bool) (ret b) q u))
  -- merge/clocked/correct (suc k) (x ∷ xs) (y ∷ ys) (s≤s h) (h₁ ∷ sorted₁) (h₂ ∷ sorted₂) u | ub/intro {q = q} false _ h-eq | ofⁿ ¬p =
  --   let h = Eq.subst (Nat._≤ k) (N.+-suc (length xs) (length ys)) h in
  --   let (l , ≡ , ↭ , sorted) = merge/clocked/correct k (x ∷ xs) ys h (h₁ ∷ sorted₁) sorted₂ u in
  --   let p = ≰⇒≥ ¬p in
  --   y ∷ l , (
  --     let open ≡-Reasoning in
  --     begin
  --       step' (F (list A)) q (bind (F (list A)) (merge/clocked k (x ∷ xs , ys)) (ret ∘ (y ∷_)))
  --     ≡⟨ step'/ext (F (list A)) (bind (F (list A)) (merge/clocked k _) _) q u ⟩
  --       bind (F (list A)) (merge/clocked k (x ∷ xs , ys)) (ret ∘ (y ∷_))
  --     ≡⟨ Eq.cong (λ e → bind (F (list A)) e _) ≡ ⟩
  --       ret (y ∷ l)
  --     ∎
  --   ) , (
  --     let open PermutationReasoning in
  --     begin
  --       (x ∷ xs ++ y ∷ ys)
  --     ↭⟨ ++-comm (x ∷ xs) (y ∷ ys) ⟩
  --       (y ∷ ys ++ x ∷ xs)
  --     ≡⟨⟩
  --       y ∷ (ys ++ x ∷ xs)
  --     <⟨ ++-comm ys (x ∷ xs) ⟩
  --       y ∷ (x ∷ xs ++ ys)
  --     <⟨ ↭ ⟩
  --       y ∷ l
  --     ∎
  --    ) , All-resp-↭ (↭) (++⁺-All (p ∷ ≤-≤* p h₁) h₂) ∷ sorted
  -- merge/clocked/correct (suc k) (x ∷ xs) (y ∷ ys) (s≤s h) (h₁ ∷ sorted₁) (h₂ ∷ sorted₂) u | ub/intro {q = q} true  _ h-eq | ofʸ p =
  --   let (l , ≡ , ↭ , sorted) = merge/clocked/correct k xs (y ∷ ys) h sorted₁ (h₂ ∷ sorted₂) u in
  --   x ∷ l , (
  --     let open ≡-Reasoning in
  --     begin
  --       step' (F (list A)) q (bind (F (list A)) (merge/clocked k (xs , y ∷ ys)) (ret ∘ (x ∷_)))
  --     ≡⟨ step'/ext (F (list A)) (bind (F (list A)) (merge/clocked k _) _) q u ⟩
  --       bind (F (list A)) (merge/clocked k (xs , y ∷ ys)) (ret ∘ (x ∷_))
  --     ≡⟨ Eq.cong (λ e → bind (F (list A)) e _) ≡ ⟩
  --       ret (x ∷ l)
  --     ∎
  --   ) , prep x ↭ , All-resp-↭ (↭) (++⁺-All h₁ (p ∷ ≤-≤* p h₂)) ∷ sorted

  -- merge/clocked/length : ∀ k (l₁ l₂ : val (list A)) (κ : ℕ → α) →
  --   bind (meta α) (merge/clocked k (l₁ , l₂)) (κ ∘ length) ≡ κ (length l₁ + length l₂)
  -- merge/clocked/length zero    l₁       l₂       κ = Eq.cong κ (length-++ l₁)
  -- merge/clocked/length (suc k) []       l₂       κ = refl
  -- merge/clocked/length (suc k) (x ∷ xs) []       κ = Eq.cong (κ ∘ suc) (Eq.sym (N.+-identityʳ (length xs)))
  -- merge/clocked/length (suc k) (x ∷ xs) (y ∷ ys) κ with h-cost x y
  -- ... | ub/intro false _ h-eq rewrite eq/ref h-eq =
  --   begin
  --     bind _ (merge/clocked k (x ∷ xs , ys)) (λ l → (κ ∘ length) (y ∷ l))
  --   ≡⟨⟩
  --     bind _ (merge/clocked k (x ∷ xs , ys)) (λ l → (κ ∘ suc) (length l))
  --   ≡⟨ merge/clocked/length k (x ∷ xs) ys (κ ∘ suc) ⟩
  --     κ (suc (length (x ∷ xs) + length ys))
  --   ≡˘⟨ Eq.cong κ (N.+-suc (length (x ∷ xs)) (length ys)) ⟩
  --     κ (length (x ∷ xs) + length (y ∷ ys))
  --   ∎
  --     where open ≡-Reasoning
  -- ... | ub/intro true  _ h-eq rewrite eq/ref h-eq =
  --   begin
  --     bind _ (merge/clocked k (xs , y ∷ ys)) (λ l → (κ ∘ length) (x ∷ l))
  --   ≡⟨⟩
  --     bind _ (merge/clocked k (xs , y ∷ ys)) (λ l → (κ ∘ suc) (length l))
  --   ≡⟨ merge/clocked/length k xs (y ∷ ys) (κ ∘ suc) ⟩
  --     κ (suc (length xs + length (y ∷ ys)))
  --   ≡⟨⟩
  --     κ (length (x ∷ xs) + length (y ∷ ys))
  --   ∎
  --     where open ≡-Reasoning

  -- merge/clocked/cost : cmp (Π (U (meta ℕ)) λ _ → Π pair λ _ → cost)
  -- merge/clocked/cost k _ = k , k

  -- merge/clocked≤merge/clocked/cost : ∀ k p → ub (list A) (merge/clocked k p) (merge/clocked/cost k p)
  -- merge/clocked≤merge/clocked/cost zero    (l₁     , l₂    ) = ub/ret
  -- merge/clocked≤merge/clocked/cost (suc k) ([]     , l₂    ) = ub/relax (z≤n , z≤n) ub/ret
  -- merge/clocked≤merge/clocked/cost (suc k) (x ∷ xs , []    ) = ub/relax (z≤n , z≤n) ub/ret
  -- merge/clocked≤merge/clocked/cost (suc k) (x ∷ xs , y ∷ ys) =
  --   ub/bind/const (1 , 1) (k , k) (h-cost x y)
  --     λ { false → ub/bind/const' (k , k) 𝟘 (⊕-identityʳ _) (merge/clocked≤merge/clocked/cost k _) λ _ → ub/ret
  --       ; true  → ub/bind/const' (k , k) 𝟘 (⊕-identityʳ _) (merge/clocked≤merge/clocked/cost k _) λ _ → ub/ret }

  merge : cmp (Π pair λ _ → F (list A))
  merge (l₁ , l₂) = merge/clocked (length l₁ + length l₂) (l₁ , l₂)  -- TODO: refine clock

  -- merge/correct : ∀ l₁ l₂ → Sorted l₁ → Sorted l₂ →
  --   ◯ (∃ λ l → merge (l₁ , l₂) ≡ ret l × SortedOf (l₁ ++ l₂) l)
  -- merge/correct l₁ l₂ = merge/clocked/correct (length l₁ + length l₂) l₁ l₂ N.≤-refl

  -- merge/length : ∀ l₁ l₂ (κ : ℕ → α) → bind (meta α) (merge (l₁ , l₂)) (κ ∘ length) ≡ κ (length l₁ + length l₂)
  -- merge/length l₁ l₂ = merge/clocked/length (length l₁ + length l₂) l₁ l₂

  -- merge/cost : cmp (Π pair λ _ → cost)
  -- merge/cost (l₁ , l₂) = merge/clocked/cost (length l₁ + length l₂) (l₁ , l₂)

  -- merge≤merge/cost : ∀ p → ub (list A) (merge p) (merge/cost p)
  -- merge≤merge/cost (l₁ , l₂) = merge/clocked≤merge/clocked/cost (length l₁ + length l₂) (l₁ , l₂)

  sort/clocked : cmp (Π (U (meta ℕ)) λ _ → Π (list A) λ _ → F (list A))
  sort/clocked zero    l = ret l
  sort/clocked (suc k) l =
    bind (F (list A)) (split l) λ (l₁ , l₂) →
      bind (F (list A)) (sort/clocked k l₁ & sort/clocked k l₂) merge

  -- sort/clocked/correct : ∀ k l → ⌈log₂ length l ⌉ Nat.≤ k → SortResult (sort/clocked k) l
  -- sort/clocked/correct zero    l h u = l , refl , refl , short-sorted (⌈log₂n⌉≡0⇒n≤1 (N.n≤0⇒n≡0 h))
  -- sort/clocked/correct (suc k) l h u =
  --   let (l₁ , l₂ , ≡ , length₁ , length₂ , ↭) = split/correct l u in
  --   let (l₁' , ≡₁ , ↭₁ , sorted₁) = sort/clocked/correct k l₁ (
  --                                     let open ≤-Reasoning in
  --                                     begin
  --                                       ⌈log₂ length l₁ ⌉
  --                                     ≡⟨ Eq.cong ⌈log₂_⌉ length₁ ⟩
  --                                       ⌈log₂ ⌊ length l /2⌋ ⌉
  --                                     ≤⟨ log₂-mono (N.⌊n/2⌋≤⌈n/2⌉ (length l)) ⟩
  --                                       ⌈log₂ ⌈ length l /2⌉ ⌉
  --                                     ≤⟨ log₂-suc (length l) h ⟩
  --                                       k
  --                                     ∎
  --                                   ) u in
  --   let (l₂' , ≡₂ , ↭₂ , sorted₂) = sort/clocked/correct k l₂ (
  --                                     let open ≤-Reasoning in
  --                                     begin
  --                                       ⌈log₂ length l₂ ⌉
  --                                     ≡⟨ Eq.cong ⌈log₂_⌉ length₂ ⟩
  --                                       ⌈log₂ ⌈ length l /2⌉ ⌉
  --                                     ≤⟨ log₂-suc (length l) h ⟩
  --                                       k
  --                                     ∎
  --                                   ) u in
  --   let (l' , ≡' , ↭' , sorted) = merge/correct l₁' l₂' sorted₁ sorted₂ u in
  --   l' , (
  --     let open ≡-Reasoning in
  --     begin
  --       sort/clocked (suc k) l
  --     ≡⟨⟩
  --       (bind (F (list A)) (split l) λ (l₁ , l₂) →
  --         bind (F (list A)) (sort/clocked k l₁ & sort/clocked k l₂) merge)
  --     ≡⟨ Eq.cong (λ e → bind (F (list A)) e _) ≡ ⟩
  --       bind (F (list A)) (sort/clocked k l₁ & sort/clocked k l₂) merge
  --     ≡⟨ Eq.cong (λ e → bind (F (list A)) e merge) (Eq.cong₂ _&_ ≡₁ ≡₂) ⟩
  --       bind (F (list A)) (ret l₁' & ret l₂') merge
  --     ≡⟨ bind/par 𝟘 𝟘 ⟩
  --       merge (l₁' , l₂')
  --     ≡⟨ ≡' ⟩
  --       ret l'
  --     ∎
  --   ) , (
  --     let open PermutationReasoning in
  --     begin
  --       l
  --     ↭⟨ ↭ ⟩
  --       l₁ ++ l₂
  --     ↭⟨ ++⁺-↭ ↭₁ ↭₂ ⟩
  --       l₁' ++ l₂'
  --     ↭⟨ ↭' ⟩
  --       l'
  --     ∎
  --   ) , sorted

  -- sort/clocked/length : ∀ k l (κ : ℕ → α) → bind (meta α) (sort/clocked k l) (κ ∘ length) ≡ κ (length l)
  -- sort/clocked/length {_} zero    l κ = refl
  -- sort/clocked/length {α} (suc k) l κ =
  --   begin
  --     bnd (sort/clocked (suc k) l) (κ ∘ length)
  --   ≡⟨⟩
  --     (bnd (split l) λ (l₁ , l₂) →
  --       bnd (sort/clocked k l₁ & sort/clocked k l₂) λ (l₁' , l₂') →
  --         bnd (merge (l₁' , l₂')) (κ ∘ length))
  --   ≡⟨
  --     Eq.cong (bnd (split l)) (funext λ (l₁ , l₂) →
  --       Eq.cong (bnd (sort/clocked k l₁ & sort/clocked k l₂)) (funext λ (l₁' , l₂') →
  --         merge/length l₁' l₂' κ
  --       )
  --     )
  --   ⟩
  --     (bnd (split l) λ (l₁ , l₂) →
  --       bnd (sort/clocked k l₁ & sort/clocked k l₂) λ (l₁' , l₂') →
  --         κ (length l₁' + length l₂'))
  --   ≡⟨
  --     Eq.cong (bnd (split l)) (funext λ (l₁ , l₂) →
  --       {!   !}
  --     )
  --   ⟩
  --     (bnd (split l) λ (l₁ , l₂) →
  --       κ (length l₁ + length l₂))
  --   ≡⟨ split/length l (λ n₁ n₂ → κ (n₁ + n₂)) ⟩
  --     κ (⌊ length l /2⌋ + ⌈ length l /2⌉ )
  --   ≡⟨ Eq.cong κ (N.⌊n/2⌋+⌈n/2⌉≡n (length l)) ⟩
  --     κ (length l)
  --   ∎
  --   where
  --     open ≡-Reasoning

  --     bnd : ∀ {A} → cmp (F A) → (val A → α) → α
  --     bnd = bind (meta α)

  -- sort/clocked/cost : cmp (Π (U (meta ℕ)) λ _ → Π (list A) λ _ → cost)
  -- sort/clocked/cost zero    l = 𝟘
  -- sort/clocked/cost (suc k) l =
  --   bind cost (split l) λ (l₁ , l₂) → split/cost l ⊕
  --     bind cost (sort/clocked k l₁ & sort/clocked k l₂) λ (l₁' , l₂') → (sort/clocked/cost k l₁ ⊗ sort/clocked/cost k l₂) ⊕
  --       merge/cost (l₁' , l₂')

  -- sort/clocked/cost/closed : cmp (Π (U (meta ℕ)) λ _ → Π (list A) λ _ → cost)
  -- sort/clocked/cost/closed k l = k * length l , 2 * length l + k

  -- sort/clocked/cost≤sort/clocked/cost/closed : ∀ k l → sort/clocked/cost k l P≤ sort/clocked/cost/closed k l
  -- sort/clocked/cost≤sort/clocked/cost/closed zero    l = z≤n , z≤n
  -- sort/clocked/cost≤sort/clocked/cost/closed (suc k) l =
  --   let open P≤-Reasoning in
  --   begin
  --     sort/clocked/cost (suc k) l
  --   ≡⟨⟩
  --     (bind cost (split l) λ (l₁ , l₂) → split/cost l ⊕
  --       bind cost (sort/clocked k l₁ & sort/clocked k l₂) λ (l₁' , l₂') → (sort/clocked/cost k l₁ ⊗ sort/clocked/cost k l₂) ⊕
  --         merge/cost (l₁' , l₂'))
  --   ≡⟨⟩
  --     (bind cost (split l) λ (l₁ , l₂) → split/cost l ⊕
  --       bind cost (sort/clocked k l₁ & sort/clocked k l₂) λ (l₁' , l₂') → (sort/clocked/cost k l₁ ⊗ sort/clocked/cost k l₂) ⊕
  --         (length l₁' + length l₂' , length l₁' + length l₂'))
  --   ≡⟨ {!   !} ⟩
  --     (bind cost (split l) λ (l₁ , l₂) → split/cost l ⊕
  --       ((sort/clocked/cost k l₁ ⊗ sort/clocked/cost k l₂) ⊕
  --         (length l₁ + length l₂ , length l₁ + length l₂)))
  --   ≤⟨ {!   !} ⟩
  --     (bind cost (split l) λ (l₁ , l₂) → split/cost l ⊕
  --       ((sort/clocked/cost/closed k l₁ ⊗ sort/clocked/cost/closed k l₂) ⊕
  --         (length l₁ + length l₂ , length l₁ + length l₂)))
  --   ≡⟨⟩
  --     (bind cost (split l) λ (l₁ , l₂) → split/cost l ⊕
  --       (((k * length l₁ , 2 * length l₁ + k) ⊗ (k * length l₂ , 2 * length l₂ + k)) ⊕
  --         (length l₁ + length l₂ , length l₁ + length l₂)))
  --   ≡⟨ split/length l (λ n₁ n₂ → ((k * n₁ , 2 * n₁ + k) ⊗ (k * n₂ , 2 * n₂ + k)) ⊕ (n₁ + n₂ , n₁ + n₂)) ⟩
  --     (split/cost l ⊕
  --       ((k * ⌊ length l /2⌋ , 2 * ⌊ length l /2⌋ + k) ⊗ (k * ⌈ length l /2⌉ , 2 * ⌈ length l /2⌉ + k)) ⊕
  --         (⌊ length l /2⌋ + ⌈ length l /2⌉ , ⌊ length l /2⌋ + ⌈ length l /2⌉))
  --   ≡⟨ ⊕-identityˡ _ ⟩
  --     ((k * ⌊ length l /2⌋ , 2 * ⌊ length l /2⌋ + k) ⊗ (k * ⌈ length l /2⌉ , 2 * ⌈ length l /2⌉ + k)) ⊕
  --       (⌊ length l /2⌋ + ⌈ length l /2⌉ , ⌊ length l /2⌋ + ⌈ length l /2⌉)
  --   ≡⟨
  --     Eq.cong (((k * ⌊ length l /2⌋ , 2 * ⌊ length l /2⌋ + k) ⊗ (k * ⌈ length l /2⌉ , 2 * ⌈ length l /2⌉ + k)) ⊕_) (
  --       Eq.cong₂ _,_ (N.⌊n/2⌋+⌈n/2⌉≡n (length l)) (N.⌊n/2⌋+⌈n/2⌉≡n (length l))
  --     )
  --   ⟩
  --     ((k * ⌊ length l /2⌋ , 2 * ⌊ length l /2⌋ + k) ⊗ (k * ⌈ length l /2⌉ , 2 * ⌈ length l /2⌉ + k)) ⊕
  --       (length l , length l)
  --   ≤⟨ arithmetic/work (length l) , arithmetic/span (length l) ⟩
  --     suc k * length l , 2 * length l + suc k
  --   ≡⟨⟩
  --     sort/clocked/cost/closed (suc k) l
  --   ∎
  --     where
  --       arithmetic/work : ∀ n → k * ⌊ n /2⌋ + k * ⌈ n /2⌉ + n Nat.≤ suc k * n
  --       arithmetic/work n =
  --         begin
  --           k * ⌊ n /2⌋ + k * ⌈ n /2⌉ + n
  --         ≡⟨ N.+-comm _ n ⟩
  --           n + (k * ⌊ n /2⌋ + k * ⌈ n /2⌉)
  --         ≡˘⟨ Eq.cong₂ (_+_) (N.*-identityˡ _) (N.*-distribˡ-+ k _ _) ⟩
  --           1 * n + k * (⌊ n /2⌋ + ⌈ n /2⌉)
  --         ≡⟨ Eq.cong (λ m → 1 * n + k * m) (N.⌊n/2⌋+⌈n/2⌉≡n n) ⟩
  --           1 * n + k * n
  --         ≡˘⟨ N.*-distribʳ-+ _ 1 k ⟩
  --           suc k * n
  --         ∎
  --           where open ≤-Reasoning

  --       lemma/2n≡n+n : ∀ n → 2 * n ≡ n + n
  --       lemma/2n≡n+n n = Eq.cong (λ m → n + m) (N.+-identityʳ n)

  --       arithmetic/span : ∀ n → (2 * ⌊ n /2⌋ + k) ⊔ (2 * ⌈ n /2⌉ + k) + n Nat.≤ 2 * n + suc k
  --       arithmetic/span n =
  --         begin
  --           (2 * ⌊ n /2⌋ + k) ⊔ (2 * ⌈ n /2⌉ + k) + n
  --         ≤⟨ N.+-monoˡ-≤ n (N.⊔-monoˡ-≤ (2 * ⌈ n /2⌉ + k) (N.+-monoˡ-≤ k (N.*-monoʳ-≤ 2 (N.⌊n/2⌋≤⌈n/2⌉ n)))) ⟩
  --           (2 * ⌈ n /2⌉ + k) ⊔ (2 * ⌈ n /2⌉ + k) + n
  --         ≡⟨ Eq.cong (_+ n) (N.⊔-idem _) ⟩
  --           2 * ⌈ n /2⌉ + k + n
  --         ≡⟨ N.+-assoc (2 * ⌈ n /2⌉) k n ⟩
  --           2 * ⌈ n /2⌉ + (k + n)
  --         ≡⟨ Eq.cong (_+ (k + n)) (lemma/2n≡n+n ⌈ n /2⌉) ⟩
  --           (⌈ n /2⌉ + ⌈ n /2⌉) + (k + n)
  --         ≡⟨⟩
  --           (⌊ suc n /2⌋ + ⌈ n /2⌉) + (k + n)
  --         ≤⟨ N.+-monoˡ-≤ (k + n) (N.+-monoʳ-≤ ⌊ suc n /2⌋ (N.⌈n/2⌉-mono (N.n≤1+n n))) ⟩
  --           (⌊ suc n /2⌋ + ⌈ suc n /2⌉) + (k + n)
  --         ≡⟨ Eq.cong (_+ (k + n)) (N.⌊n/2⌋+⌈n/2⌉≡n (suc n)) ⟩
  --           suc n + (k + n)
  --         ≡⟨⟩
  --           suc (n + (k + n))
  --         ≡⟨ Eq.cong (λ m → suc (n + m)) (N.+-comm k n) ⟩
  --           suc (n + (n + k))
  --         ≡˘⟨ Eq.cong suc (N.+-assoc n n k) ⟩
  --           suc ((n + n) + k)
  --         ≡˘⟨ N.+-suc (n + n) k ⟩
  --           (n + n) + suc k
  --         ≡˘⟨ Eq.cong (_+ suc k) (lemma/2n≡n+n n) ⟩
  --           2 * n + suc k
  --         ∎
  --           where open ≤-Reasoning

  -- sort/clocked≤sort/clocked/cost : ∀ k l → ub (list A) (sort/clocked k l) (sort/clocked/cost k l)
  -- sort/clocked≤sort/clocked/cost zero l = ub/ret
  -- sort/clocked≤sort/clocked/cost (suc k) l =
  --   ub/bind _ _ (split≤split/cost l) λ (l₁ , l₂) →
  --     ub/bind _ _ (ub/par (sort/clocked≤sort/clocked/cost k l₁) (sort/clocked≤sort/clocked/cost k l₂)) λ (l₁' , l₂') →
  --       merge≤merge/cost (l₁' , l₂')

  -- sort/clocked≤sort/clocked/cost/closed : ∀ k l → ub (list A) (sort/clocked k l) (sort/clocked/cost/closed k l)
  -- sort/clocked≤sort/clocked/cost/closed k l = ub/relax (sort/clocked/cost≤sort/clocked/cost/closed k l) (sort/clocked≤sort/clocked/cost k l)

  sort/depth : cmp (Π (list A) λ _ → meta ℕ)
  sort/depth l = ⌈log₂ length l ⌉

  sort : cmp (Π (list A) λ _ → F (list A))
  sort l = sort/clocked (sort/depth l) l

  -- sort/correct : IsSort sort
  -- sort/correct l = sort/clocked/correct (sort/depth l) l N.≤-refl

  -- sort/cost : cmp (Π (list A) λ _ → cost)
  -- sort/cost l = sort/clocked/cost (sort/depth l) l

  -- sort/cost/closed : cmp (Π (list A) λ _ → cost)
  -- sort/cost/closed l = sort/clocked/cost/closed (sort/depth l) l

  -- sort≤sort/cost : ∀ l → ub (list A) (sort l) (sort/cost l)
  -- sort≤sort/cost l = sort/clocked≤sort/clocked/cost (sort/depth l) l

  -- sort≤sort/cost/closed : ∀ l → ub (list A) (sort l) (sort/cost/closed l)
  -- sort≤sort/cost/closed l = sort/clocked≤sort/clocked/cost/closed (sort/depth l) l

module Ex/MergeSortFast where
  module Sort = MergeSortFast NatComparable

  list' = list (U (meta ℕ))

  ex/split : cmp (F Sort.pair)
  ex/split = Sort.split (6 ∷ 2 ∷ 8 ∷ 3 ∷ 1 ∷ 8 ∷ 5 ∷ [])

  ex/splitMid : cmp (F Sort.triple)
  ex/splitMid = Sort.splitMid test/forward (s≤s z≤n)

  ex/splitBy : cmp (F Sort.pair)
  ex/splitBy = Sort.splitBy test/forward 5

  ex/merge : cmp (F list')
  ex/merge = Sort.merge (2 ∷ 3 ∷ 6 ∷ 8 ∷ [] , 1 ∷ 5 ∷ 8 ∷ [])

  ex/sort : cmp (F list')
  ex/sort = Sort.sort (1 ∷ 5 ∷ 3 ∷ 1 ∷ 2 ∷ [])

  ex/sort/forward : cmp (F list')
  ex/sort/forward = Sort.sort test/forward  -- cost: ?

  ex/sort/backward : cmp (F list')
  ex/sort/backward = Sort.sort test/backward  -- cost: ?

  ex/sort/shuffled : cmp (F list')
  ex/sort/shuffled = Sort.sort test/shuffled  -- cost: ?

module SortEquivalence (M : Comparable) where
  open Comparable M
  open Core M

  module ISort = InsertionSort M
  module MSort = MergeSort M

  isort≡msort : ◯ (ISort.sort ≡ MSort.sort)
  isort≡msort u =
    funext λ l →
      let (l'ᵢ , ≡ᵢ , ↭ᵢ , sortedᵢ) = ISort.sort/correct l u in
      let (l'ₘ , ≡ₘ , ↭ₘ , sortedₘ) = MSort.sort/correct l u in
      begin
        ISort.sort l
      ≡⟨ ≡ᵢ ⟩
        ret l'ᵢ
      ≡⟨ Eq.cong ret (unique-sorted sortedᵢ sortedₘ (trans (↭-sym ↭ᵢ) ↭ₘ)) ⟩
        ret l'ₘ
      ≡˘⟨ ≡ₘ ⟩
        MSort.sort l
      ∎
        where open ≡-Reasoning
