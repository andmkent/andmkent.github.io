    Title: Design and Evaluation of Gradual Typing for Python
    Date: 2014-10-20T00:00:00
    Tags: Publications

[ACM link](http://dl.acm.org/citation.cfm?id=2661101)

At DLS '14 with Michael M. Vitousek and Jeremy G. Siek.

<!-- more -->

### Abstract

Combining static and dynamic typing within the same language offers
clear benefits to programmers. It provides dynamic typing in
situations that require rapid prototyping, heterogeneous data
structures, and reflection, while supporting static typing when
safety, modularity, and efficiency are primary concerns. Siek and Taha
(2006) introduced an approach to combining static and dynamic typing
in a fine-grained manner through the notion of type consistency in the
static semantics and run-time casts in the dynamic semantics. However,
many open questions remain regarding the semantics of gradually typed
languages.

In this paper we present Reticulated Python, a system for
experimenting with gradual-typed dialects of Python. The dialects are
syntactically identical to Python 3 but give static and dynamic
semantics to the type annotations already present in
Python 3. Reticulated Python consists of a typechecker and a
source-to-source translator from Reticulated Python to Python 3. Using
Reticulated Python, we evaluate a gradual type system and three
approaches to the dynamic semantics of mutable objects: the
traditional semantics based on Siek and Taha (2007) and Herman et
al. (2007) and two new designs. We evaluate these designs in the
context of several third-party Python programs.
