    Title: C to Racket Examples
    Date: 2014-03-24T09:16:07
    Tags: Racket, C

### Racket and C

This post is a collection of simple C code snippets and roughly
equivalent Racket code.

Hopefully if you're coming from a C background (or similar) and you're
struggling to make sense of Racket code, these examples will assist in
clearing the fog and help bring about the utter bliss that is programming
in Racket =)

<!-- more -->

<br/>

![Racket is a descendant of Lisp (comic from
 [xkcd](http://www.xkcd.com))](http://imgs.xkcd.com/comics/lisp_cycles.png)


<br/>

### "I need more!"

If you wish for a more in depth introduction to Racket, I recommend
perusing the excellent [Racket
Guide](http://docs.racket-lang.org/guide/). If you're curious about a
particular function the [Racket manuals](http://docs.racket-lang.org/)
are a great resource. If I've configured the page correctly, library
functions in the code snippets should link to their manual entries.


<br/>

*If your beginning your first venture into the world of
 [functional
 programming](http://en.wikipedia.org/wiki/Functional_programming),
 you'll want to do some reading to understand the norms of this world
 vs. what's likely been ingrained into your being from years of
 imperative programming (sorry I don't have a good reference for this
 as I'm writing this...)*

*Also, neither the C nor the Racket code is meant to be the epitome
 of elegance or ideal programming - they're merely there to
 demonstrate how things might be expressed in each language.*

<br/>

## Table of Contents

  1. [Preprocessor Commands](#preproc)
  2. [Values and Variables](#variab)
  3. [Arithmetic](#arith)
  4. [Structures](#struct)
  5. [Array Indexing](#array)
  6. [Local/Scoped Definitions](#scope)
  7. [Functions and Conditionals](#fun)
  8. [Recursion](#rec)
  9. [Lists and Loops](#list)
  10. [Other](#other)

<br/>

## <a name="preproc"></a>Preprocessor stuff

####C includes

```c
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>
#include <math.h>
#include <ctype.h>
#include <assert.h> 
```
####Racket #lang and requires

```racket
#lang racket
; we'll just need the testing suite "rackunit"
; the rest is included in the default racket language
(require rackunit)
```
<br/>

## <a name="variab"></a>Values and Variables

### Declaration and initialization

####C data

```c
int b1 = true; // true
int b2 = false; // false (only 0 is false)
int x  = 5; // int
int pi = 3.14; // float 
char c = 'a'; // char
char* str = "Hello World!"; // string

int fibs[6] = {0, 1, 1, 2, 3, 5};
```

####Racket data

```racket
(define b1 #t) ; true, #true is equivalent
(define b2 #f) ; false, #false is equivalent (the only false value)
(define x 5) ; exact-integer
(define pi 3.14) ; flonum
(define c #\a) ; character
(define str "Hello World!") ; string

; singly linked list
(define fibslist (list 0 1 1 2 3 5))
; fixed-length array with constant-time access
(define fibsvec (vector 0 1 1 2 3 5))
```

Note: small note, by default Racket lists are immutable and vectors
are mutable. Alternate versions of either are available as well (see
docs).

### Assignment (Mutation)

####C Assignment (Mutation)

```c
int x = 10; // initialization
x = 5; // assignment/mutation
assert(x == 5);
```

####Racket Mutation

```racket
(define x 10) ; initialization
(set! x 5) ; mutation
(check-equal? x 5)
```

<br/>

## <a name="arith"></a>Arithmetic

####C math

```c
int y = 1 + 2 + 3;
assert(y == 6);

int z = (4 + (2 * 3)) / 5;
assert(z == 2);
```

####Racket math

```racket
(define y (+ 1 2 3))
(check-equal? y 6)

(define z (/ (+ (* 2 3)
                4)
             5))
(check-equal? z 2)
```

<br/>

## <a name="struct"></a>Structures

### Structure Definitions

####C structs

```c
struct point {
    int x;
    int y;
};
```

####Racket structs

```racket
(define-struct point (x y))
```

Note: small note, Racket structs are immutable by default. Mutable
structs are available (see docs).

### Structure Usage

####C struct accessors

```c
struct point p = {.x = 3, .y = 4};
assert(p.x == 3);
assert(p.y == 4);
```

####Racket struct accessors

```racket
(define p (point 3 4))
(check-equal? (point-x p) 3)
(check-equal? (point-y p) 4)
```

<br/>

## <a name="array"></a>Constant-time array access

#### C array indexing

```c
int fibs[6] = {0, 1, 1, 2, 3, 5};
assert(fibs[4] == 3);
```

#### Racket vector-ref

```racket
(define fibs (vector 0 1 1 2 3 5))
(check-equal? (vector-ref fibs 4) 3)
```

## <a name="scope"></a>Local/Scoped Definitions (blocks and lets)

#### C {} blocks

```c
int x = 5;

{
    int x = 10;
    assert(x == 10);
}
    
assert(x == 5);

{
   int x = 1;
   int y = x + 10;
   assert(y == 11);
}

assert(x == 5);
```

#### Racket let expressions

```racket
(define x 5)
(let ([x 10])
  (check-equal? x 10))

(check-equal? x 5)

(let* ([x 1]
       [y (+ x 10)])
  (check-equal? y 11))

(check-equal? x 5)
```

_Note: let* allows definitions to reference identifiers previously
declared in the list of let bindings_

<br/>

## <a name="fun"></a>Function Definitions

### Basic Functions

#### C simple function

```c
int square(int x) {
    return x * x;
}

assert(square(3) == 9);
```

#### Racket simple function

```racket
(define (square x)
  (* x x))

(check-equal? (square 3) 9)
```

_Note: C functions are a series of statements with some specified
"return" statement that dictates what the function call evaluates to
(except for void, but you get the idea). Racket functions are more
like a mathematical expression that is merely simplified/evaluated to
some value and that value is returned._

### Functions that *require* in order execution

#### C command line interaction

```c
int square_input() {
    char str[50];
    int num;

    printf("\n Enter input: ");
    scanf("%[^\n]+", str);

    num = atoi(str);

    return num * num;
}

// Enter number: 7
// 49
```

#### Racket command line interaction & begin

```racket
(define (square-input)
  (begin
    (printf "\n Enter number: ")
    (define input (read))
    (* input input)))

; Enter number: 9
; 81
```

### Functions with Conditional Control Flow

#### C if-else

```c
int int_abs(int x) {
    if (x < 0)
        return (-1) * x;
    else
        return x;
}

assert(int_abs(1) == 1);
assert(int_abs(-1) == 1);
```

#### Racket if-else

```racket
(define (int-abs x)
  (if (< x 0)
      (* -1 x)
      x))

(check-equal? (int-abs 1) 1)
(check-equal? (int-abs -1) 1)
```

#### C if-else-if-else-if...

```c
// returns number of real roots that exist
int real_quad_roots(int a, int b, int c) {
    float d = (b*b) - 4.0*a*c;

    if (d < 0) {
        return 0;
    } else if (d == 0) {
        return 1;
    } else {
        return 2;
    }
}

// (2x+2)(x-5) = 2x^2 - 8x - 10
assert(real_quad_roots(2, -8, -10) == 2);
// (x-5)(x-5) = x^2 - 10x + 25
assert(real_quad_roots(1, -10, 25) == 1);
// x^2 + 4   no roots
assert(real_quad_roots(1, 0, 4) == 0);
```

#### Racket if-else-if-else... _i.e._ cond

```racket
(define (real-quad-roots a b c)
  (let ([d (- (* b b)
              (* 4 a c))])
    (cond
      [(< d 0) 0]
      [(= d 0) 1]
      [else    2])))

(check-equal? (real-quad-roots 2 -8 -10)
              2)
(check-equal? (real-quad-roots 1 -10 25)
              1)
(check-equal? (real-quad-roots 1 0 4)
              0)

; We can also use internal defines instead of a let:
(define (real-quad-roots2 a b c)
  (define d (- (* b b)
               (* 4 a c)))
  (cond
    [(< d 0) 0]
    [(= d 0) 1]
    [else    2]))

; defines inside functions act just like the let version above, and
; you can just stick them in there (they don't have to contain a "body
; expression" like a let)

(check-equal? (real-quad-roots2 2 -8 -10)
              2)
(check-equal? (real-quad-roots2 1 -10 25)
              1)
(check-equal? (real-quad-roots2 1 0 4)
              0)
```

#### C function with structs

```c
float distance(struct point *p1, 
               struct point *p2) {
    assert(p1 != NULL && p2 != NULL);

    int dx = p1->x - p2->x;
    int dy = p1->y - p2->y;

    return sqrt((dx * dx) + (dy * dy));
}

struct point p1 = {.x = 0, .y = 0};
struct point p2 = {.x = 3, .y = 4};
assert(distance(&p1, &p2) == 5);
```

#### Racket function with structs

```racket
(define (distance p1 p2)
  (begin
    (when (not (and (point? p1) 
                    (point? p2)))
      (error 'distance "Error - invalid parameter"))
    (let ([dx (- (point-x p1)
                 (point-x p2))]
          [dy (- (point-y p1)
                 (point-y p2))])
      (sqrt (+ (* dx dx)
               (* dy dy))))))

(define p1 (point 0 0))
(define p2 (point 3 4))
(check-equal? (distance p1 p2) 5)
```


<br/>

## <a name="rec"></a>Recursive Functions

#### C recursion

```c
long factorial_rec(int n)
{
  if (n == 0)
    return 1;
  else
    return(n * factorial(n-1));
}

assert(factorial(5) == 120);
```

#### Racket recursion

```racket
(define (factorial x)
  (if (zero? x)
      1
      (* x (factorial (sub1 x)))))

(check-equal? (factorial 5) 120)
```

#### C recursion on linked lists

```c
// a non-empty linked list
// is an element (first) followed by
// a linked list (the rest)
struct list {
    int first;
    struct list* rest;
};

int length(struct list* l) {
    if (l == NULL)
        return 0;
    else
        return 1 + length(l->rest);
}

struct list node3 = {.first = 2, .rest = NULL};
struct list node2 = {.first = 1, .rest = &node3};
struct list node1 = {.first = 0, .rest = &node2};

assert(length(&node1) == 3);
```

#### Racket recursion on lists

```racket

; Lists in Racket?
(check-equal? empty empty)
(check-equal? (list 1) (cons 1 empty))
(check-equal? (list 1 2) (cons 1 (cons 2 empty)))
; list is shorthand for lists built with cons
(check-equal? (first (list 1 2)) 1)
(check-equal? (rest (list 1 2)) (cons 2 empty))

(define (length l)
  (cond
    [(empty? l)
     0]
    [else
     (add1 (length (rest l)))]))

(check-equal? (length (list 0 2 4)) 
              3)
(check-equal? (length (cons 0 (cons 2 (cons 4 empty)))) 
              3)
```

<br/>

## <a name="list"></a>Lists and Loops

#### C recursive list building

```c
// builds list 0 through (i-1) from back
// to front
#define make_range(n) range_loop(n, NULL)
struct list* range_loop(int i, struct list *rest) {
    if (i > 0) {
        struct list *new = malloc(sizeof(struct list));
        new->first = i - 1;
        new->rest = rest;

        return range_loop(i - 1, new);
    } 
    else {
        return rest;    
    }
}

struct list *l = make_range(3);
// we verify (painfully) the list is indeed [0, 1, 2]
assert(l->first == 0);
assert(l->rest->first == 1);
assert(l->rest->rest->first == 2);
assert(l->rest->rest->rest == NULL);
```

#### Racket recursive list construction (using a "let-loop")

```racket
; return list of numbers 0 to (n-1)
(define (make-range n)
  (let range-loop ([i n]
                   [l empty])
    (if (positive? i)
        (range-loop (sub1 i)
                    (cons (sub1 i) l))
        l)))

(check-equal? (make-range 3)
              (list 0 1 2))
```

#### C list sum with loop

```c
int listsum(struct list* l) {
    struct list* i = l;
    int sum = 0;
    while (i != NULL) {
        sum = sum + i->first;
        i = i->rest;
    }

    return sum;
}

// make_range from previous example
// builds list of 0 through (n-1)
assert(listsum(make_range(4)) == 6);
```

#### Racket list sum with for loop

```racket
(define (listsum l)
  (define sum 0)
  (begin (for ([i l])
           (set! sum (+ sum i)))
         sum))

; make-range from previous example
(check-equal? (listsum (make-range 4)) 6)
```

#### C list building loop

```c
struct list* n_evens(int n) {
    int i, value;
    struct list *head, *prev;
    head = prev = NULL;

    for (i = 0; i < n; i++) {
        value = 2 * i;
        struct list *new = malloc(sizeof(struct list));
        new->first = value;
        if (prev != NULL)
            prev->rest = new;
        else
            head = new;
        prev = new;
    }

    prev->rest = NULL;

    return head;
}

l = n_evens(3); // l = [0, 2, 4]
assert(l->first == 0);
assert(l->rest->first == 2);
assert(l->rest->rest->first == 4);
assert(l->rest->rest->rest == NULL);
```

#### Racket for/list loop

```racket
; make-range is built into Racket, and is called just range:
(check-equal? (range 3) (list 0 1 2))

; Builds list of the first n even natural numbers
(define (n-evens n)
  (for/list ([i (range n)])
    (* 2 i)))

(check-equal? (n-evens 3) (list 0 2 4))
```

#### C loop that finds max integer

```c
int max_in_list(struct list *l) {
    int max = l->first;
    struct list *i = l->rest;

    while (i != NULL) {
        if (max < i->first)
            max = i->first;
        else
            max = max;

        i = i->rest;
    }

    return max;
}

struct list l3 = {.first = 12, .rest = NULL};
struct list l2 = {.first = 99, .rest = &l3};
struct list l1 = {.first = 42, .rest = &l2};
assert(max_in_list(&l1) == 99);
```

#### Racket for/fold loop that finds max integer

```racket
(define (max-in-list l)
  (for/fold ([max (first l)]) ([i (rest l)])
    (if (< max i)
        i
        max)))

(check-equal? (max-in-list (list 42 99 12)) 99)
```


<br/>

## <a name="other"></a>Last but not least... Functional tools!

In addition to various ways to write functions that may resemble code
you've seen in C, there are also a plethora of elegant, beautiful
tools at your fingertips which you should start digging into.

For example, you'll want to learn about some of the list functions
like filter, map, fold, etc...

```racket
; returns list with only even numbers
(define (only-even l)
  (filter even? l))

(check-equal? (only-even (list 0 1 2 3 4))
              (list 0 2 4))

; returns list with numbers squared
(define (square-list l)
  (map (λ (x) (* x x)) l))

(check-equal? (square-list (list 0 1 1 2 3 5))
              (list 0 1 1 4 9 25))

; takes a list of strings and returns the sum of their lengths
(define (str-len-sum lostr)
  (foldl (λ (str sum)
           (+ sum (string-length str)))
         0 
         lostr))

(check-equal? (str-len-sum (list "cat" "dogs" "ferret"))
              13)
```