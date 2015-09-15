#lang scribble/manual

Title: Quicksort in Coq
Date: 2014-11-10T09:01:16
Tags: Coq, Dependent Types

@(require frog/scribble)

Coq's support for dependent types mean that type checking not only
catches trivial errors like passing an integer to a function expecting
a string, but it can also check and verify types which represent
properties regarding the functional behavior of the a program.

I thought it would be edifying to use this capability to write a
verified version of quicksort (i.e. a quicksort with types that
specify its behavior), and it was!

<!-- more -->

@section[#:style 'unnumbered]{Basic Quicksort}

So first let's just write quicksort, and then we'll see
what dependent types can add.

@subsection[#:style 'unnumbered]{A First Attempt}


This was my initial attempt at writing quicksort in Coq (first w/o the
more complex types):

@pygment-code[#:lang "coq"]{
Fixpoint quicksort (l:list nat) : list nat :=
match l with
  | nil => nil
  | x :: xs =>
      let (lhs, rhs) := partition (gtb x) xs in
      (quicksort lhs) ++ x :: (quicksort rhs)
end.
}

Looked pretty good, I thought! It was nice and simple... until I tried
to compile it:

@pygment-code[#:lang "coq"]{
Error:
Recursive definition of quicksort is ill-formed.
In environment
quicksort : list nat -> list nat
l : list nat
x : nat
xs : list nat
rhs : list nat
lhs : list nat
Recursive call to quicksort has principal argument
equal to "lhs" instead of "xs"...
}

Of course - my recursive calls are not structurally recursive
(i.e. they're not on the structural pieces that make up the input),
so Coq isn't convinced our recursive calls will terminate.

@margin-note{Coq requires all programs to be total and deterministic
             to ensure its logic is sound.}

@subsection[#:style 'unnumbered]{Guaranteeing Termination}

Doing a little digging, I discover that one way to write 
functions which Coq cannot infer termination for is
using the keywords "Program" and "measure":

@pygment-code[#:lang "coq"]{
Program Fixpoint quicksort
      (l:list nat)
      {measure (length l)} : list nat :=
match l with
| nil => nil
| x :: xs =>
    match partition (leb x) xs with
    | (rhs, lhs) =>
      (quicksort lhs) ++ x :: (quicksort rhs)
    end
end.
}

Now Coq knows that the decreasing argument to be measured is the
length of the input (from {measure (length l)}), and it knows that I
am... "Program"-ing... err... I mean it may also generate
@emph{proof obligations} from this fixpoint definition (which is what 
Program specifies).

Okay, so I compiled it and then I got some new messages (woohoo!).

@pygment-code[#:lang "coq"]{
quicksort has type-checked, generating 3 obligation(s)
Solving obligations automatically...
quicksort_obligation_3 is defined
2 obligations remaining
Obligation 1 of quicksort:
forall l : list nat,
(forall l0 : list nat, length l0 < length l -> list nat) ->
forall (x : nat) (xs : list nat),
x :: xs = l ->
let filtered_var := partition (leb x) xs in
forall rhs lhs : list nat, (rhs, lhs) = filtered_var ->
                 length lhs < length l.

Obligation 2 of quicksort:
forall l : list nat,
(forall l0 : list nat, length l0 < length l -> list nat) ->
forall (x : nat) (xs : list nat),
x :: xs = l ->
let filtered_var := partition (leb x) xs in
forall rhs lhs : list nat, (rhs, lhs) = filtered_var ->
                 length rhs < length l.
}

Cool - two obligations. To solve these (which just verify the length
of the inputs to the recursive calls (lhs and rhs) are <= the length
of the original input) I used "Next Obligation of quicksort." twice,
applying a little theorem proving where needed. After proving both, I
got:

@pygment-code[#:lang "coq"]{
No more obligations remaining
quicksort is defined
}

Side note: You may have noticed I swapped out the "let" statement in the
original attempt for a "match" statement - but why? Well, using the
"let" left me proving the facts about lhs and rhs without any evidence
as to where they came from. Match, on the other hand, gave me the
assumption "(lhs, rhs) = partition (gtb x) xs", which was important
since that fact was key to proving their size was less than the
original input. Kind of lame that I couldn't use the let (it seemed
more direct and elegant), but oh well.

@section[#:style 'unnumbered]{Verified Quicksort}

So writing quicksort wasn't too bad. I learned a little about how
proof obligations work with respect to the termination of
fixpoints. But what about verifying it actually sorts the list we've
given it? How do we know it is correct?

@subsection[#:style 'unnumbered]{Is testing good enough?}

I could throw a few tests cases at it to feel a little better 
about its correctness:

@pygment-code[#:lang "coq"]{
Example qs_nil:
  quicksort [] = [].
Proof.
  auto.
Qed.

Example qs_ex1:
  quicksort [3 ; 2 ; 1] = [1 ; 2 ; 3].
Proof with auto.
  compute...
Qed.
}

But we still can't be 100% certain it is correct. In fact, in this case
a list reverse would have passed these tests! So in general, what 
can we do if we want to @emph{formally verify} a program? 
In a language like Coq there are multiple ways to do this!

@subsection[#:style 'unnumbered]{Proving Quicksort Correct with Dependent Types}

There's two primary approaches to verifying functions in Coq: 
You can write a theorem stating quicksort is correct and
prove it valid, or you can add the specification to the type
of quicksort itself. Let's do the latter.


@pygment-code[#:lang "coq"]{
Program Fixpoint quicksort
      (l:list nat)
      {measure (length l)} :
      {sl : list nat |
        Permutation l sl
        /\ StronglySorted le sl} :=
match l with
| nil => nil
| x :: xs =>
    match partition (gtb x) xs with
    | (lhs, rhs) =>
      (quicksort lhs) ++ x :: (quicksort rhs)
    end
end.
}

This approach looks like our original version, except that our return
type is not merely a list of nat, but a list of nat such that it is a
permutation of the original and it is sorted (yes, that is all in the
return type). Obligations for the predicate portion of the return type
(Permutation l sl /\ StronglySorted le sl) must be proven as well if
Coq cannot automatically prove them (and in this case, it cannot).

The first obligation related to the return type is for the empty list
case (nil), which is trivial (since quicksort merely returns nil,
which is a permutation of nil and is sorted). In the second such
obligation, we assume these properties hold for the recursive calls
(quicksort lhs) and (quicksort rhs) (that they produce sorted
partitions of their input - this is our inductive hypothesis) and
prove these properties are maintained by (quicksort lhs) ++ x ::
(quicksort rhs). With the use of a few lemmas related to partitioning
and appending sorted lists that are related (such as how our two are
in this case) this isn't these properties aren't too bad to verify.

Suggestions and comments always welcome =)