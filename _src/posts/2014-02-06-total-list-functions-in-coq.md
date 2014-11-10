    Title: Total List Functions
    Date: 2014-02-06T22:36:50
    Tags: Coq, Program Verification, Dependent Types

What is the type of a function which returns the first element of a
list? One possible (and likely common) answer would be:

```racket
(: first (All (X) ((Listof X) -> X)))
```

This (typed racket syntax) says _first_ is a function from a list of
X's to an X (where X is any type). However, we really know that,
although its type is ((Listof X) -> X), if we pass an empty list of X
we will not get an X, but a runtime error of some sort (e.g. no
values). The type then isn't really giving us a guarantee of what it
will do for us... it's just telling us what it will _try_ to do for us
if it doesn't fail.

_"No. Try not. Do... or do not. There is no try." - Master Yoda_

There is a parallel in math: some functions are not defined for all
possible input values (e.g. f(x)=1/x). These are called partial
functions (as opposed to total functions). It is common practice to
reserve the term "function" for total functions in math, while in
programming partial functions are ubiquitous and there is little
effort to distinguish between the two.  If only there was some way
that the types could reflect this possibility...

<!-- more -->

_Note: The property of being total in theoretical computer science is
also referred to as the strong normalization property._

In type theory, the type that has no values is commonly called the
[bottom type](http://en.wikipedia.org/wiki/Bottom_type). It is often
written as ⊥ (\bot in LaTeX). Thus we could say _first_ has type
((Listof X) -> (U X ⊥)),  or in other words, we define our return type as
the union of types X and ⊥ to reflect that not returning anything (the
bottom type ⊥) is an option.

Type systems often dodge/ignore this problem by merely guaranteeing
that they will prevent all _type errors_ and not _run-time errors_,
with a definition of _type errors_ that to them is reasonable and
suites their needs. Lets assume, however, that we did not wish to
ignore ⊥ and that we wanted our type checking to provide stronger
guarantees about what happens in our program. We could approach this
by using a type with an explicit failure case for _first_ (i.e. wrap
the return value in a "maybe"), thus forcing us to always return a
failure value (or similar) instead of error or exit. The other option
(and the one we will explore) is to use types which limit the domain
of the function so that the function _becomes_ total (e.g. dissallow
empty lists in the type itself so first _always_ returns an X).

## Sigma Types

In a previous post while examining what a verified version of
quicksort might look like, I included the properties I desired _in_
the return type:

```coq
Program Fixpoint quicksort
        (l:list nat) {measure (length l)} :
        {sl : list nat | Permutation l sl
                         /\ StronglySorted le sl} :=
```

That is, the return type of this function is not merely a list, but a
list and a proof it is a permutation of the input and strongly
sorted. This was done using Coq's Sigma-types:

From the Coq manual: _Subsets and Sigma-types (sig A P), or more
suggestively {x:A | P x}, denotes the subset of elements of the type A
which satisfy the predicate P._

Similarly, Sigma-types can help us in our endeavor to devise robust,
total list functions.

## Writing a total "first"

What we really want to do is say that our function "first" is not
merely of type ((Listof X) -> X), but it additionally requires the
input list be non-empty and it returns the first element of it.

Now we can attempt write our total version of first:

```coq
Definition strong_first {X:Type} (l:list X) (pf: l <> nil): X :=
match l, pf with
  | nil, _ => match reflneq pf with end
  | x :: xs, _ =>  x
end.
```

strong_first takes a list l and a proof it is not null and returns an
X.

It accomplishes this by matching the list against the possible two
structural forms for a list:

_nil case_: If it is empty, we use the proof that nil <> nil with the following lemma:

```coq
Lemma reflneq {X:Type} : forall x : X, x <> x -> False.
Proof.
  auto.
Qed.
```

This gives us False within our function, which we use to vacuously
satisfy the match statement for the nil case (since False has exactly
0 constructors).

_cons case_: In the cons case, we merely return the first element, x.

If we were designing a complex system that used this function, if/when
we extracted the code out of Coq into another language (OCaml in this
case) we get:

```ocaml
let strong_first = function
| Nil -> assert false (* absurd case *)
| Cons (x, xs) -> x
```

And although this function _seems_ to have the problem we originally
sought to solve (it errors on some input allowed by the OCaml type
system), this case would _never_ be reached by any code also verified
and extracted in Coq (since the type checking in Coq would have
_ensured_ the list was non-empty). As for whether or not external code
calls this function incorrectly (i.e. with an empty list), that is a
matter that must be handled separately. One approach would be the way
Typed Racket ensures that typed and untyped modules play nicely:
it wraps interactions between untyped and typed code in contracts that
perform dynamic checks to prevent any such "mixed type error."

## A verified return value

We can also, as we did with quicksort, add a specification to the
return type via a Sigma-type so our specification is more precise.

```coq
Definition strong_first' {X: Type} (l:list X) (pf: l <> nil):
{x:X| exists xs, l = x :: xs} :=
match l, pf with
  | nil, _ => match reflneq pf with end
  | x :: xs, _ => x
end.
```

Unfortunately, as we see when we try to compile this, we are now
returning only the element and not the proof of it's first-ness:

```coq
The term "x" has type "X" while it is expected to have type
{x0 : X | exists xs0 : list X, ?25 = x0 :: xs0}"
```

We will take this as an opportunity to exploit the ability to change
perspectives and instead approach this in Coq's interactive proving
mode:

```coq
Definition strong_first' {X:Set} :
forall (l : list X) (pf:l <> nil),
  {x : X | exists xs, l = x :: xs}.
```

This creates a proof goal that matches the signature of the function
we wish to write:

```coq
 X : Set
============================
 forall l : list X, l <> nil ->
   {x : X | exists xs : list X, l = x :: xs}
```

We can then use the refine tactic:

_8.2.3 refine term: This tactic applies to any goal. It behaves like
exact with a big difference: the user can leave some holes (denoted by
_ or (_:type)) in the term. refine will generate as many subgoals as
there are holes in the term. The type of holes must be either
synthesized by the system or declared by an explicit cast like
(_:nat->Prop). This low-level tactic can be useful to advanced users._

```coq
  refine
(fun l pf =>
   match l, pf with
     | nil, _ => False_rec _ _
     | x :: xs, _ => exist _ x _
   end).
```

_Note: We used False_rec instead of the empty match cases we did
previously. They're really the same thing when you flesh them all the
way out._

```coq
False_rec
: forall P : Set, False -> P
```

False_rec just hides some of the machinery and the _ wholes allow us
to give Coq's automation a chance to fill in the gaps for us.

This is what remains in our goals:

```coq
2 subgoals, subgoal 1 (ID 41)

  X : Set
  l : list X
  pf : l <> nil
  pf0 : nil <> nil
  ============================
   False

subgoal 2 (ID 45) is:
 exists xs0 : list X, x :: xs = x :: xs0

Abort.
```

From here we can see the resulting goals are relatively simple, and so
we can supplement the refine with a call to eauto. We will also define
and use some notation which can be useful if writing numerous
functions in this fashion:

```coq
Notation ">><<" := (False_rec _ _).
Notation ">> x <<" := (False_rec _ x).
Notation "[ e ]" := (exist _ e _).

Definition strong_first' {X:Set} :
  forall (l : list X) (pf:l <> nil),
    {x : X | exists xs, l = x :: xs}.
  refine
    (fun l pf =>
       match l, pf with
         | nil, _ => >><<
         | x :: xs, _ => [x]
       end); eauto.
Defined.

Extraction strong_first'.
```

It's the same extracted function, and it now has the specified output! Cool.

```coq
(** val strong_first' : 'a1 list -> 'a1 **)

let strong_first' = function
  | Nil -> assert false (* absurd case *)
  | Cons (x, xs) -> x
```

Now let's see if we can apply this strategy to devise a verified
list-indexing function!

## Verified List-Indexing

First we define a lemma or two that will be used in our definition:

```coq
Lemma lt_list {X:Type} : forall (x:X) xs n,
S n < length (x :: xs) ->
n < length xs.
Proof.
  crush.
Qed.

Lemma ltnil (X:Type): forall n,
n < length nil -> False.
Proof.
  crush.
Qed.
```

Note: I wrote these as I saw I needed them, obviously. By "first", I
mean we need these defined first =)

We also define a notion which can capture the idea we have for what it
means to return the correct nth item from a list:

```coq
Inductive ListIndex {X:Set} : nat -> X -> list X -> Prop :=
| LInil : forall x xs, ListIndex 0 x (x::xs)
| LIcons : forall n x' x xs,
             ListIndex n x' xs ->
             ListIndex (S n) x' (x::xs).
Hint Constructors ListIndex.
```

And for convenience... I define a shorter, more clear name for the
function that extracts the item out of a sigma type:

```coq
Definition sigX := proj1_sig.

Definition strong_nth {X:Set} :
  forall (l : list X) (i : nat) (pf:i < length l),
    {x : X | ListIndex i x l}.
  refine
    (fix f (l:list X) (i:nat) (pf: i < length l) :
       {x : X | ListIndex i x l} :=
       match l, i, pf with
         | x::xs, 0, _ => [x]
         | x::xs, S i', _ =>  [sigX (f xs i' (lt_list pf))]
         | _, _, _ => >>ltnil pf<<
       end); crush.
```

We're almost there. The crush tactic derived everything except the
details regarding the fact that our recursive call's type is
equivalent to (or implies, perhaps) the type we wish to return from
the initial call:

```coq
 X : Set
  f : forall (l : list X) (i : nat),
      i < length l -> {x : X | ListIndex i x l}
  l : list X
  i : nat
  pf : i < length l
  x : X
  xs : list X
  pf0 : i < S (length xs)
  i' : nat
  pf1 : S i' < S (length xs)
  ============================
   ListIndex (S i') (sigX (f xs i' (lt_list pf1))) (x :: xs)

Abort.
```

We simply build a lemma that extends the proof to meet our needs,
given what we get from the recursive call and we're good to go:

```coq
Lemma nthrec {X: Set}: forall l i h (x: {x : X | ListIndex i x l}),
i < length l ->
ListIndex (S i) (proj1_sig x) (h::l).
Proof.
  intros.
  destruct x. crush.
Qed.
Hint Resolve nthrec.

Definition strong_nth {X:Set} :
  forall (l : list X) (i : nat) (pf:i < length l),
    {x : X | ListIndex i x l}.
  refine
    (fix f (l:list X) (i:nat) (pf: i < length l) :
       {x : X | ListIndex i x l} :=
       match l, i, pf with
         | x::xs, 0, _ => [x]
         | x::xs, S i', _ =>  [sigX (f xs i' (lt_list pf))]
         | _, _, _ => >>ltnil pf<<
       end); crush.
Defined.
```

So how is this different from our first example (first)?

I had to explicitly tell it I wanted to derive false from the lemma
ltnil. Without that it would "complete", but the result would be
ill-typed and fail when closing the proof with "Defined". Can't leave
everything up to automation I guess =) Because of the recursive nature
of this function, I had to build a lemma which evaluated the
Sigma-type of the recursive call and showed from it we could derive
the type we wished to ultimately return.

And here's what she looks like extracted:

```coq
(** val strong_nth : 'a1 list -> nat -> 'a1 **)

let rec strong_nth l i =
  match l with
  | Nil -> assert false (* absurd case *)
  | Cons (x, xs) ->
    (match i with
     | O -> x
     | S i' -> sigX (strong_nth xs i'))
```

Beautiful!

Source code related to this post found [here](https://github.com/sgtamk/sgtamk.github.io/blob/master/snippets/20140206-listbasics-code.v).

Note: This post is inspired by some of my personal experimenting and
some related material from the "Subset" chapter from
[CPDT](http://adam.chlipala.net/cpdt/) (an excellent Coq resource!).