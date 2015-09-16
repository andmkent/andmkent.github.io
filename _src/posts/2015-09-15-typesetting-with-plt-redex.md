    Title: Typesetting with PLT Redex
    Date: 2015-09-15T11:53:52
    Tags: Racket

[PLT Redex](http://redex.racket-lang.org/index.html) is a great tool
for tinkering with and examining various aspects of programming
languages. Although it can be used to _programmatically generate
mathematical figures_ for papers and the like (awesome!), the actual
machinery for doing so is a little lower level than you want 99% of
the time.

To alleviate this, I developed a package
([typeset-rewriter](https://github.com/andmkent/typeset-rewriter)) with a few
simple tools that make it much easier to build the rewriters redex
natively supports.

<!-- more -->

To demonstrate, let's take a simple redex model and look at
typesetting it.

## STLC Definition

First we define the language, like the simply typed lambda calculus:

```racket
#lang racket
(require redex)

(define-language STLC
  [x   ::= variable-not-otherwise-mentioned]
  [v   ::= integer true false add1 not zero?]
  [exp ::= x v (if exp_1 exp_2 exp_3)
           (lambda [x : ty] exp) (exp_1 exp_2)]
  [ty  ::= int bool (ty_1 -> ty_2)]
  [Env ::= ([x ty] ...)])
```

Note: In this definition we _could_ have used unicode characters directly
(and then typesetting will use those same characters) but we
shouldn't feel obligated to. We can throw in all the greek we want
when typesetting.

<br>

And maybe we have some judgments and metafunctions:

```racket

(define-judgment-form STLC
  #:mode (typeof I I O)
  #:contract (typeof Env exp ty)

  [----------------- "T-Val"
   (typeof Env v (val-type v))]
  
  [(where ty (lookup Env x))
   ---------- "T-Var"
   (typeof Env x ty)]

  ....)

(define-metafunction STLC
  val-type : v -> ty
  ....)

(define-metafunction STLC
  extend : Env x ty -> Env
  ....)

(define-metafunction STLC
  lookup : Env x -> ty
  ....)
```
_"..." in this case is not special syntax, but just to stand in for
the obvious definitions_

<br>

## Vanilla Typesetting

If we were to try and typeset these definitions now,
we probably wouldn't be too happy with the result:

```racket
(render-judgment-form typeof)
(with-rws (render-language STLC #:nts '(v exp ty Env)))
```

Sure, the figures will have the expected shape overall, but
maybe we wanted the more traditional `Γ` for type environments
instead of `Env`, and we probably want our typing judgments
to look like `Γ ⊢ e : τ` instead of the default typesetting
 `typeof〚Γ, e, τ〛`.

<br>

## Advanced Typesetting

In addition to a few simple knobs and switches, PLT Redex model
typesetting can be enhanced with two forms of rewriters.

### Atomic rewriters

[Atomic rewriters](http://docs.racket-lang.org/search/index.html?q=with-atomic-rewriter)
will get us part of the way there. They allow us to rewrite symbols
with provided strings (or thunks returning picts), and things like
subscripts are preserved just the way we would hope:

```racket
(with-atomic-rewriter
 'Env "Γ"
 (with-atomic-rewriter
  't 'τ
  (render-language STLC #:nts '(v exp ty Env))))
```
  
<br>

I'm not sure why there isn't a plural version of this form... so I went ahead and
defined one in the `typeset-rewriter` package:

```racket
(with-atomic-rewriters
 (['Env "Γ"] ['exp "e"] ['ty "τ"] ['-> "→"] ['integer "n"])
 (render-language STLC #:nts '(v exp ty Env)))
```

But if we want to get our typing judgment to look correct, we're going
to need just a little more muscle.

<br>

### Compound Rewriters

The hooks for
[compound rewriters](http://docs.racket-lang.org/search/index.html?q=with-compound-rewriter)
are pretty powerful. They allow us to transform arbitrary redex terms
by letting us specify _compound rewriters_ to be applied to parenthesized terms
with a particular symbol at the head. So if we install a rewriter `lambda-rw`
before typesetting

```racket
(with-compound-rewriter
 'lambda lambda-rw
 (render-language STLC #:nts '(v exp ty Env)))
```

any term of the form `(lambda any ...)` will be passed to our `lambda-rw`
procedure.

<br>

This gives us great power... but if we look at the signature for these rewriters
we see the catch:

```racket
(listof lw) -> (listof (or/c lw? string? pict?))
```

We have to work with lists of the `lw` structs that redex uses to typeset
code if we want to tweak how our figures will look.

To make this more palatable, I built a macro that abstracts away all
the struct details of our redex terms and lets us use the much simpler
`quasiquote` and `unquote` syntax we're used to working with in Racket
[pattern matching](http://docs.racket-lang.org/reference/match.html).

<br>

With these tools, we can define the following rewriters and rewriting context:

```racket

(require typeset-rewriter)

(define lambda-rw
  (rw [`(lambda ([,x : ,t]) ,body)
       => (list "λ" x ":" t ". " body)]
      [`(lambda ([,x : ,t]) ,body ,bodies ...)
      => (list* "λ" x ":" t ". (begin " body (append bodies (list ")")))]))
      
(define typeof-rw
  (rw [`(typeof ,Γ ,e ,t)
       => (list "" Γ " ⊢ " e " : " t)]))

(define extend-rw
  (rw [`(extend ,Γ ,x ,t)
       => (list "" Γ ", " x ":" t)]))

(define lookup-rw
  (rw [`(lookup ,Γ ,x)
       => (list "" Γ "(" x ")")]))

(define val-type-rw
  (rw [`(val-type ,v)
       => (list "type-of(" v ")")]))

(define-rw-context with-rws
  #:atomic (['Env "Γ"] ['exp "e"] ['ty "τ"] ['-> "→"] ['integer "n"])
  #:compound (['lambda lambda-rw]
              ['typeof typeof-rw]
              ['extend extend-rw]
              ['lookup lookup-rw]
              ['val-type val-type-rw]))

```

<br>

This allows us to produce figures looking just the way we want:

```racket
(with-rws (render-language STLC #:nts '(v exp ty Env)))
(with-rws (render-judgment-form typeof))
```

![](/img/pltredexstlc.png)

<br>

## Further Customizations

You may have noticed I used a more complex definition for `lambda-rw`
than seemed necessary:

```racket
(define lambda-rw
  (rw [`(lambda ([,x : ,t]) ,body)
       => (list "λ" x ":" t ". " body)]
      [`(lambda ([,x : ,t]) ,body ,bodies ...)
       => (list* "λ" x ":" t ". (begin " body (append bodies (list ")")))]))
```

This was just to show that the `rw` macro is merely a thin layer of
syntax that expands into Racket's powerful `match` form. Anything
following an `unquote` (_e.g. a `,`_) in the `quasiquote` pattern
can be an arbitrary match pattern, and things like elipses---since
they are supported by `match`---are supported as well.

<br>

## Installing and using `typeset-rewriter`

From the command line, enter

` raco pkg install typeset-rewriter `

Or from within DrRacket, open the Package Manager (`File>Package Manager` on Mac),
enter `typeset-rewriter` in the `Package Source` field and install.

After installation, simply add `typeset-rewriter` to the list of
required packages in your module. Ex `(require redex
typeset-rewriter)`.

<br>
