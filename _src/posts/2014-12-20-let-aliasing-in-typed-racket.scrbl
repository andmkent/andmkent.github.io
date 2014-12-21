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

@itemlist[@item{@racket[y] is of type @racket[(U Number String)]}
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
is a kind of syntactic representation of some expression. If an expression
'has an object,' it means there is some pure syntactic representation
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
or @racket[((λ (maybe-num) (number? maybe-num)) x)]
as it does from @racket[(number? x)].

@section[#:style 'unnumbered]{A Simple Solution: Let-aliasing Objects}

In desire to keep things simple and maintain compatibility with what 
Typed Racket is already doing so well for so many other Racket programs, 
I decided to explore adding a simple aliasing extension to the current 
type system that behaves in the following ways:

@itemlist[@item{Add a function, @racket[θ], to the type environment, which 
                maps identifiers to objects.}
          @item{By default, @racket[θ] acts like the identity function, mapping
                identifiers to themselves.}
          @item{@racket[θ] is extended only if, when typechecking a 
                 let-expression, a variable is being bound to an expression
                 with an object. This extension is only in effect while checking 
                 the body of that let expression.}
          @item{When typechecking any variable expression, 
                @racket[x], reason about the object @racket[(θ x)]
                instead of @racket[x].}]

So, for example, when typechecking the @emph{body} of the let expression in 
@racket[foo-let], we extend the aliasing lookup @racket[θ] in the 
type environment to map @racket[y] to the object @racket[x] instead of adding
the three propositions relating @racket[x] and @racket[y] we saw earlier.

This simple approach allows the type system to seemlessly track let-aliasing
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

@subsection[#:style 'unnumbered]{So ins't this just copy propogation?}

It's definitely similar --- both reason about known equalities between 
expressions and have to be aware of mutation (our use of objects handles this)
 --- however, we're not modifying the source program as a separate pass. We're keeping
the same program and just trying to edify the typechecker (without adding additional
passes) with the same kinds of insights it could have if it was typehecking a 
program that had been rewritten using copy propogation or a similar technique.

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

Let-aliasing almost gets us there, but the environment in which @racket[f3]
is typechecked doesn't know that we're only going to call it if @racket[x1]
is not a number =(

Perhaps this is an argument for why let-aliasing should be a little more like 
copy propogation...? We'll have to do some more digging and find out!

@subsection[#:style 'unnumbered]{So how much of the Typed Racket codebase had to change to support this?}

Not that much! @hyperlink["https://github.com/racket/typed-racket/pull/2"
"Here's"] the Github pull request. I had to improve TR's ability to update
type information inside of complex structures a little (e.g. @racket[cons] cells, 
@racket[struct]s) since there were no longer additional variables floating 
around explicitly representing things like the @racket[(car p)], for example, 
but these changes were fairly natural/minor and perhaps should have been 
made regardless.

@subsection[#:style 'unnumbered]{Where can I learn more about TR's type system?}

Start here: 'Logical Types for Untyped Languages' by Tobin-Hochstadt and Felleisen
[@hyperlink["http://dl.acm.org/citation.cfm?id=1863561"
"ACM link"]]




