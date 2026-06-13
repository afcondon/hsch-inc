# purescript-native — C++

<p class="meta-row"><strong>Target:</strong> native C++ (and a Go variant) ·
<strong>Lineage:</strong> source-emitter ·
<strong>By:</strong> Andy Arvanitis ·
<strong>Status:</strong> established ·
<strong>Repo:</strong> <a href="https://github.com/andyarvanitis/purescript-native">andyarvanitis/purescript-native</a></p>

The long-standing native backend — PureScript to C++, with a companion Go
target and an FFI (`go-ffi`). It borrows **native compilation**: no VM, direct
machine code, C/C++ interop.

Note: our own [psgo](psgo/) is a *separate, from-scratch* Go emitter — distinct
from this project's Go variant. The local clone of `purescript-native` is the
reference for the Go column's FFI conventions, though `go-ffi` tracks an older
core-library era, so expect the *least* coverage here — each gap is a "library
coverage" data point for the matrix.

> This page is a stub — a candidate full column. Semantic divergences (Int is
> 64-bit, UTF-8 strings, strconv-based float formatting) to be filled from
> observed facts.
