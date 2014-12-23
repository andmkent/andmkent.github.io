#lang scribble/manual

Title: Let-aliasing in Typed Racket
Date: 2014-12-20T08:23:08
Tags: Typed Racket


Although Typed Racket (TR) @emph{can} currently typecheck a large number 
of common idioms found in Racket code, reasoning about direct and indirect
usages of aliasing has escaped its grasp... until now!

<!-- more -->

@section[#:style 'unnumbered]{Motivation for Aliasing}

Typed Racket's use of logical propositions about types enables 
it to typecheck programs whose control flows don't neatly fit 
within the realm of what traditional type systems can check.

Here, for example, the type checker recognizes the result of 
@racket[(number? x)] has type-related implications, whether it
evaluates to @racket[#t] or @racket[#f]:

@racketblock[(: foo (Any -> Number))
             (define (size x)
               (cond
                 [(number? x) x]
                 [else 42]))]


That's great--but if we introduce just a little indirection:

@codeblock{
(: foo-let (Any-> Number))
(define (foo-let x)
  (let ([y x])
    (cond
      [(number? y) x]
      [else 42])))
;; does not typecheck in Racket version <= 6.1.1  =(
}

We discover that, even though @racket[y] was bound to @racket[x],
that information does not make it into the type-system. 
Instead, the only information that relates the two values is 
(more or less) the following three propositions:

@itemlist[@item{@racket[y] is of type @racket[Any]}
          @item{If @racket[y] evaluates to @racket[#f], @racket[x]
                   is of type @racket[False].}
          @item{If @racket[y] evaluates to a non-@racket[#f] value, 
                   @racket[x] is not of type @racket[False].}]


Now, you may be thinking @racket[foo-let] doesn't typecheck because
no one should ever write such a silly program! However, many of Racket's 
useful macros expand into code which requires just this sort of 
type-based reasoning:

@codeblock{
(: foo-match (Any -> Number))
(define (foo-match x)
  (match x
    [(? number?) x]
    [_ 42]))
;; does not typecheck in Racket version <= 6.1.1
;; because match expands into a program utilizing let-bindings
}

It sure would be nice if we could get some of these seemingly simple 
programs (and more!) to typecheck without a big refactoring of
the type system...

@section[#:style 'unnumbered]{A slight aside: What is an object in TR?}

In the calculus which describes Typed Racket's type system, an 'object'
is a syntactic representation of an expression. If an expression
`has an object,' then there is some pure syntactic representation
for the value it will evaluate to. Currently, objects can represent variables
or accesses into immutable values such as @racket[cons] cells or 
@racket[structs]. For example:

@tabular[#:sep @hspace[1]
         (list (list @bold{Racket Expression}      @bold{TR Object})
               (list @racket[x]                    @racket[x])
               (list @racket[(random 100)]         "No Object")
               (list @racket[(caar p)]             @racket[(car (car p))])
               (list @racket[((λ (x) x) y)]        @racket[y])
               (list @racket[(string-length s)]    "No Object")
               (list @racket[((λ (x) y) 42)]       @racket[y]))]

Basically, objects enable the type system derive the same
logical meaning from expressions like @racket[(number? ((λ () x)))]
or @racket[((λ (a) (number? a)) x)]
as it does from @racket[(number? x)].

@section[#:style 'unnumbered]{A Simple Solution: Let-aliasing Objects}

In desire to keep things simple and maintain compatibility with what 
Typed Racket already does so well, I decided to explore adding a simple 
aliasing extension to the current type system.

@subsection[#:style 'unnumbered]{Let-aliasing overview}

My goal was to implement the following changes:

@itemlist[@item{Add a function @racket[θ] to the type environment which 
                maps identifiers to objects. By default, @racket[θ] just 
                maps identifiers to themselves.}
          @item{@racket[θ] is extended when a let-expression binds an expression
                 with an object to a variable. This extension is only in effect 
                 while checking the body of that let-expression.}
          @item{When typechecking any variable expression, 
                @racket[x], pretend your considering the object @racket[o] 
                (where @racket[o = (θ x)]) instead.}]

So, for example, when typechecking the @emph{body} of the let-expression in 
@racket[foo-let], we extend @racket[θ] with the mapping @racket[(y -> x)]
instead of adding the three propositions relating @racket[x] and @racket[y] 
we saw earlier:

@codeblock{
(: foo-let (Any-> Number))
(define (foo-let x)
  (let ([y x])  ;; <- we extend θ, mapping 'y' to the object 'x',
    (cond              ;; making references to 'y' be viewed
      [(number? y) x]  ;; as references to 'x' here within
      [else 42])))     ;; the body of the let
}

@subsection[#:style 'unnumbered]{Type Judgments}

Another way to describe this change is to observe the changes to the
type judgments affecting let-expressions and variables.

Here are the original typing judgments (in a PLT Redex-ish format) 
from `Logical Types for Untyped Languages' by Tobin-Hochstadt and 
Felleisen [@hyperlink["http://dl.acm.org/citation.cfm?id=1863561" "ACM link"]]

@racketblock[
[(Proves Γ_1 (x_1 -: τ_1))
 ------------------------ "T-Var"
 (TypeOf Γ_1 x_1 τ_1 (x_1 -! False) (x_1 -: False) x_1)]
                                                        
[(TypeOf Γ_1 e_0 τ_0 ψ_0+ ψ_0- o_0)
 (where Γ_2 (cons (And (x_0 -: τ_0)
                       (Or (And (x_0 -! False) ψ_0+)
                           (And (x_0 -: False) ψ_0-))) 
                  Γ_1))
 (TypeOf Γ_2 e_1 τ_1 ψ_1+ ψ_1- o_1)
 ------------------------ "T-Let"
 (TypeOf Γ_1 
         (let ([x_0 e_0]) e_1) 
         τ_1  [o_0 / x_0] 
         ψ_1+ [o_0 / x_0]
         ψ_1- [o_0 / x_0]
         o_1  [o_0 / x_0])]
]

Where @racket[(TypeOf Γ e τ ψ ψ o)] is a 5-place relation with the 
following arguments:

@itemlist[@item{@racket[Γ] is the current type environment.}
           @item{@racket[e] is the expression being typechecked.}
           @item{@racket[τ] is the type of @racket[e].}
           @item{The first @racket[ψ] is what we learn if @racket[e] evaluates
                 to be a non-@racket[#f] value.}
           @item{The second @racket[ψ] is what we learn if @racket[e] evaluates
                 to @racket[#f].}
          @item{@racket[o] is the object of @racket[e].}]
          
@racket[(Proves Γ ψ)] is a 2-place relation which holds when the 
environment of propositions @racket[Γ] can prove the proposition @racket[ψ]. 

@racket[(x_1 -: τ_1)] and @racket[(x_1 -! τ_1)] are propositions 
which mean @racket[x_1] is or is not of some type @racket[τ_1], respectively.

@racket[[o_0 / x_0]] placed next to something means to 
substitute @racket[o_0] for @racket[x_0] within that something.

Here are the let-aliasing versions that replace those rules (note we add
a place for @racket[θ] next to @racket[Γ]):

@codeblock{
[(where o_x (lookup θ_1 x_1))
 (Proves Γ_1 (o_x -: τ_1))
 ------------------------ "T-Var-Alias"
 (TypeOf θ_1 Γ_1 x_1 τ_1 (o_x -! False) (o_x -: False) o_x)]
                                                        
[(TypeOf θ_1 Γ_1 e_0 τ_0 ψ_0+ ψ_0- o_0)
 (where #f (equal? o_0 null))
 (where θ_2 (extend θ_1 x_0 o_0))
 (TypeOf θ_2 Γ_2 e_1 τ_1 ψ_1+ ψ_1- o_1)
 ------------------------ "T-Let-Alias"
 (TypeOf θ_1 Γ_1 (let ([x_0 e_0]) e_1) τ_1 ψ_1+ ψ_1- o_1)]

;; this one is the same as T-Let above but e_0 is required
;; to have a null object (i.e. not have an object)
[(TypeOf θ_1 Γ_1 e_0 τ_0 ψ_0+ ψ_0- null)
 (where Γ_2 (cons (And (x_0 -: τ_0)
                       (Or (And (x_0 -! False) ψ_0+)
                           (And (x_0 -: False) ψ_0-))) 
                  Γ_1))
 (TypeOf θ_1 Γ_2 e_1 τ_1 ψ_1+ ψ_1- o_1)
 ------------------------ "T-Let-No-Alias"
 (TypeOf θ_1
         Γ_1 
         (let ([x_0 e_0]) e_1) 
         τ_1  [null / x_1] 
         ψ_1+ [null / x_1]
         ψ_1- [null / x_1]
         o_1  [null / x_1])]
}

This simple approach allows the type system to seamlessly track let-aliasing
by only slightly modifying the type system's behavior for let-expressions
and variables!

With this change, TR can now successfully typecheck a variety of new programs!

@codeblock{
(: super-foo (-> Any Number))
(define super-foo
  (λ (x)
    (match x
      [(? number?) x]
      [`(_ . (_ . ,(? number?))) (cddr x)]
      [`(_ . (_ . ,(? pair? p))) 
        (if (number? (caddr x))
            (car p)
            41)]
      [_ 42])))
;; typechecks with let-aliasing!
}

Additionally, because this approach prevents several propositions from being
generated (and disjunctions no less!) some programs which took quite a while
to typecheck can now be verified immediately!


@section[#:style 'unnumbered]{Epilogue}

@subsection[#:style 'unnumbered]{So isn't this just copy propagation?}

It's definitely similar --- both reason about known equalities between 
expressions and have to be aware of mutation (our use of objects handles this)
 --- however, we're not modifying the source program as a separate pass. We're keeping
the same program and just trying to edify the typechecker (without adding additional
passes) with the same kinds of insights it could have if it was typehecking a 
program that had been rewritten using copy propagation or a similar technique.

@subsection[#:style 'unnumbered]{Are there any simple programs you're still working to typecheck?}

Sure! This simple guy doesn't typecheck:

@racketblock[
             (: size ((U Number String) -> Number))
             (define (size x)
               (match x
                 [(? number?) x]
                 [_ (string-length x)]))]

Because it expands into something like this:

@racketblock[
             (define (size-expanded x)
               (let* ([x1 x]
                      [f2 (λ () (string-length x))])
                 (if (number? x1)
                     x
                     (f2))))]

Let-aliasing almost gets us there, but the environment in which @racket[f2]
is typechecked doesn't know that we're only going to call it if @racket[x1]
is not a number =(

Perhaps this is an argument for why let-aliasing should be a little more like 
copy propagation...? We'll have to do some more digging and find out!

@subsection[#:style 'unnumbered]{So how much of the Typed Racket codebase had to change to support this?}

Not that much! @hyperlink["https://github.com/racket/typed-racket/pull/2"
"Here's"] the Github pull request. 

I had to improve TR's ability to update type information inside of 
structured types a little (e.g. @racket[cons] cells, @racket[struct]s) since 
we no longer had extra variables floating around when we did things
like  @racket[(let ([x (car p)]) ...)].

Now when two propositions like @racket[(x -: (Pairof Number Any))] and
@racket[(x -: (Pairof Any Number))] are joined, we structurally recur into
the @racket[car] and @racket[cdr] of the type and get the resulting fact
@racket[(x -: (Pairof Number Number))], which was essential to typechecking
programs which use aliases instead of new variables.

These changes were fairly natural/minor, however, and probably should have been 
made at some point even without aliasing. Aliasing just brought the matter
front and center.




