# Understanding Hylograph

*The ideas behind the library. Why it exists, what it's for, and the principles that shape its design.*

## 1. Operate directly on complex systems

Hylograph exists at least in part to go beyond data visualization for reading and understanding data and to use the same techniques to build interfaces where you manipulate the actual elements of a system directly. In many domains of the modern world - economics, ecology, energy transition, psephology, etc — we have imperatives now to directly engage with the complexity of things in ways that are not well-served by Web 2.0 HTML forms and dashboards. This is not in any way to negate the value of statistics and summaries. But as the foundational example of Anscombe's Quartet shows (and political discourse confirms daily) there are times when the statistical summary lacks discriminatory power. You can't fix what you can't measure and you can't spot a pattern that is collapsed out of existence by your statistical summary.

A concrete example of this exists in the form of [Minard](https://minard.app): a code cartography tool built entirely with Hylograph. Here, the domain is software, you have agents writing code far more rapidly than any human team ever could. Reviewing line by line undoes much of the benefit and makes the reviewer an extremely tight bottleneck. In Minard, by contrast you see all the modules, all the functions, dependencies, data flows as visual objects. More importantly you see relationships between things that are simply not perceptible in a Git PR. You click, hover, brush, and drag *them*. The visualization *is* the interface.

Treemaps show module size. Force-directed graphs show dependency structure. Beeswarms show change frequency. Edge bundles show call relationships. Each of these is a direct manipulation surface, not a report. This is the application of Edward Tufte's idea "to clarify, add detail" to interface design.

## 2. The hylomorphism: unfold data, fold structure

This library system builds upon a lot of previous work. Most obvious is probably Mike Bostock's incredibly successful and useful D3.js. We'll discuss the "js" part later but just conceptually here we're concerned with the mechanism independent of language.

D3's "data join" can be seen to be a special case of a more general operation. In Hylograph, a visualization is a *hylomorphism*: an unfold that takes data apart (the enumeration) composed with a fold that assembles output (the assembly). Any input shape composes with any output shape.

An array can unfold into a tree. A tree can fold into a flat list. A map can project three different ways into the same diagram. The fold doesn't care what shape the data has — it only needs to know how to take one step.

*See: [The Hylographic Fold](https://afcondon.github.io/purescript-hylograph-selection/) — Chapters 0–3 of the interactive demo.*

*See: [The Morphism Zoo](https://afcondon.github.io/purescript-psd3-prim-zoo-mosh/) — type substitution walkthrough showing how abstract morphisms specialise to concrete operations.*

## 3. Enumeration × Assembly

This re-conceptualization of the direct "join" of data elements to DOM elements allows us to tease out four concerns from one: iterating over data, creating elements, structuring the DOM, and handling updates and thus animation. *Enumeration* is how you traverse the input. *Assembly* is how you structure the output. These are independent — any enumeration strategy combines with any assembly strategy, giving you an N×M matrix of possibilities from a single primitive.

The same chess board emerges from a flat fold over 64 cells or a nested fold over 8 rows of 8. Same output, different structure — and the nested fold remembers the grouping, enabling row-level operations that the flat fold can't express. D3 has nested joins and D3 has a general update pattern but in Hylograph these are cleanly orthogonal issues.

*See: [Chapter 2: Any Structure](https://afcondon.github.io/purescript-hylograph-selection/#ch2)*

## 4. Type safety eliminates the ball of mud

Now let's return to the issues with JavaScript, the Assembly Language of the browser.

In D3.js visualization, attribute accessors are strings: `d => d.value`, JavaScript is an untyped language so this is quite normal. If the data doesn't have a `value` field, you get a blank screen. As is well-understood now - if only up to the level of type-checking of JavaScript's successor, TypeScript, this is NOT GOOD. 

It's possible to do a lot better than TypeScript, however. I'm not going to make that argument here but ML-family languages such as Haskell, PureScript, etc have much, much more powerful type systems. 

In Hylograph, attributes are typed PureScript expressions. If your accessor doesn't match the data type, the compiler tells you — before the page ever loads. And this happens without any loss of generalisability at all - because types are parameterisable. Again, this is not the place to make the argument, suffice to say that this library is written in PureScript in order to get these advantages.

This isn't an incremental improvement. It means visualization components are genuinely reusable: one bar chart implementation works for all data shapes, verified at compile time. No runtime checks, no configuration objects, no accessor strings.

With componentisation, we get the possibility of UI with visualisation techniques. When a visualization component is truly reusable and type-safe, it becomes a UI primitive — as reliable as a button or a text field, but capable of showing structure.

*See: [Chapter 4: HATS](https://afcondon.github.io/purescript-hylograph-selection/#ch4) — notice the `d.value` and `d.label` in the code are type-checked against the data.*

*See: [Hindley–Milner type system](https://en.wikipedia.org/wiki/Hindley%E2%80%93Milner_type_system) (Wikipedia) — the theoretical foundation for PureScript's type inference. *

*Also: [Propositions as Types](https://homepages.inf.ed.ac.uk/wadler/papers/propositions-as-types/propositions-as-types.pdf) (Wadler, 2015) — the deep connection between types and proofs.*

## 5. Multiple interpreters from one tree

A HATS tree is data, not instructions. It describes *what* to build, not *how*. Different interpreters walk the same tree and produce entirely different outputs: SVG for the browser, plain English for accessibility, a meta-visualization of the tree's own structure, a musical rendition of a chart for a sight-impaired user. 

This is made possible due to the *finally tagless* pattern in functional programming: you define an algebra of operations, and each interpreter provides a different semantics. The tree doesn't know or care which interpreter reads it, and amazingly it overcomes what's known as "the Expression Problem" for embedded languages. It allows us to write the functions which compute our visualisation's attributes using perfectly normal PureScript functions which in turn have available to them all the massive PureScript library ecosystem and, via FFI if necessary, JavaScript libraries too.

*See: [Chapter 5: Interpreters](https://afcondon.github.io/purescript-hylograph-selection/#ch5) and [Chapter 6: The Meta Fold](https://afcondon.github.io/purescript-hylograph-selection/#ch6)*

## 6. Visualization as active infrastructure

Many visualizations, even "interactive" ones are pretty passive — they show you what happened, perhaps allow some filtering or highlighting, maybe some brushing (all very valid and useful techniques). 

Hylograph is designed to build visualizations that are interactive in a different sense, in that the affordances of the user interface are themselves formed from visualisations. This combined with modern high-resolution displays, fast computers etc vastly increases the surface area of the UI without creating any interface "chrome" at all. You manipulate what you see.

Its particularly aimed at enabling the creation of applications where it is essential to see both detail and "big picture" at once. Where you want to project many dimensions of data down to two dimensions, which is the hallmark of great data visualization since the original Minard made his famous map of Napoleon's military adventure in Russia. 

Programmers often seem to imagine that adding a third dimension will fix the data complexity problem but, although we are stereoscopic animals we don't actually see in three dimensions, so the third dimension necessarily obscures as much as it shows. Good for games, bad for understanding the world of data that surrounds us.

For that, we need chromeless, high-resolution, direct-representation and manipulation, data-driven interfaces.

---

## Bibliography

- **Bostock, M., Ogievetsky, V., & Heer, J.** (2011). *D3: Data-Driven Documents.* IEEE Trans. Vis. & Comp. Graphics. [doi](https://doi.org/10.1109/TVCG.2011.185)
- **Meijer, E., Fokkinga, M., & Paterson, R.** (1991). *Functional Programming with Bananas, Lenses, Envelopes and Barbed Wire.* FPCA '91.
- **Carette, J., Kiselyov, O., & Shan, C.** (2009). *Finally Tagless, Partially Evaluated.* JFP 19(5).
- **Wilkinson, L.** (2005). *The Grammar of Graphics.* Springer.
- **Tufte, E.** (1983). *The Visual Display of Quantitative Information.* Graphics Press.
- **Bertin, J.** (1967). *Sémiologie Graphique.* Mouton/Gauthier-Villars.
- **Munzner, T.** (2014). *Visualization Analysis and Design.* CRC Press.
- **Victor, B.** (2011). [*Up and Down the Ladder of Abstraction.*](http://worrydream.com/LadderOfAbstraction/) worrydream.com.
- **Victor, B.** (2013). [*Drawing Dynamic Visualizations.*](https://vimeo.com/66085662) Talk at Stanford HCI.
- **Neurath, O.** (1936). *International Picture Language: The First Rules of Isotype.* Kegan Paul. — The ISOTYPE system: visual education through pictorial statistics.
- **McCandless, D.** (2009). *Information is Beautiful.* Collins.
- **Wadler, P.** (2015). [*Propositions as Types.*](https://homepages.inf.ed.ac.uk/wadler/papers/propositions-as-types/propositions-as-types.pdf) Communications of the ACM.
- **Anscombe, F. J.** (1973). *Graphs in Statistical Analysis.* The American Statistician 27(1).
- **Shneiderman, B.** (1996). *The Eyes Have It: A Task by Data Type Taxonomy for Information Visualizations.* IEEE Symposium on Visual Languages. — The mantra: overview first, zoom and filter, details on demand.
- **Card, S., Mackinlay, J., & Shneiderman, B.** (1999). *Readings in Information Visualization: Using Vision to Think.* Morgan Kaufmann.

### Further viewing

- **[Interface Studies](https://www.youtube.com/@interfacestudies)** — Saleh's excellent YouTube channel exploring the design space of direct-manipulation interfaces, interactive visualizations, and the future of human-computer interaction.
