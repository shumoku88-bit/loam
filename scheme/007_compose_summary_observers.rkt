#lang racket

(require minikanren)

;; Observation 007 stops offering finished summaries such as `pair` as
;; candidates. Instead it offers primitive observers and a composition form.
;; miniKanren searches expressions built from those pieces.

(define (history-obso h u0 u1)
  (conde
    [(== h 'h00) (== u0 #f) (== u1 #f)]
    [(== h 'h10) (== u0 #t) (== u1 #f)]
    [(== h 'h01) (== u0 #f) (== u1 #t)]
    [(== h 'h11) (== u0 #t) (== u1 #t)]))

(define (vocabularyo name ops)
  (conde
    [(== name 'none)    (== ops '())]
    [(== name 'u0-only) (== ops '(u0))]
    [(== name 'u1-only) (== ops '(u1))]
    [(== name 'both)    (== ops '(u0 u1))]))

;; Primitive observation vocabulary. These are parts, not completed summaries.
(define (primitive-observero atom)
  (conde
    [(== atom 'u0)]
    [(== atom 'u1)]
    [(== atom 'count)]))

;; Canonical two-observer combinations avoid permutation duplicates while still
;; letting the relation construct the completed summary expression.
(define (ordered-distinct-observerso left right)
  (conde
    [(== left 'u0) (== right 'u1)]
    [(== left 'u0) (== right 'count)]
    [(== left 'u1) (== right 'count)]))

;; Deliberately bounded expression grammar for this observation.
;; `one` means one primitive observer; `two` means one combine node containing
;; two distinct primitive observers.
(define (summary-expro size expr)
  (conde
    [(== size 'one)
     (fresh (atom)
       (primitive-observero atom)
       (== `(observe ,atom) expr))]
    [(== size 'two)
     (fresh (left right)
       (ordered-distinct-observerso left right)
       (== `(combine (observe ,left) (observe ,right)) expr))]))

(define (observer-valueo atom h value)
  (fresh (u0 u1)
    (history-obso h u0 u1)
    (conde
      [(== atom 'u0) (== value u0)]
      [(== atom 'u1) (== value u1)]
      [(== atom 'count)
       (conde
         [(== u0 #f) (== u1 #f) (== value 'zero)]
         [(== u0 #t) (== u1 #f) (== value 'one)]
         [(== u0 #f) (== u1 #t) (== value 'one)]
         [(== u0 #t) (== u1 #t) (== value 'two)])])))

;; Evaluate a generated summary expression against one history.
(define (summary-valueo expr h value)
  (conde
    [(fresh (atom)
       (== `(observe ,atom) expr)
       (observer-valueo atom h value))]
    [(fresh (left right left-value right-value)
       (== `(combine ,left ,right) expr)
       (summary-valueo left h left-value)
       (summary-valueo right h right-value)
       (== `(,left-value ,right-value) value))]))

(define (observableo op h value)
  (fresh (u0 u1)
    (history-obso h u0 u1)
    (conde
      [(== op 'u0) (== value u0)]
      [(== op 'u1) (== value u1)])))

;; Only compare already-ground values. Generation remains relational outside
;; this small equality boundary.
(define (same-groundo x y sameness)
  (project (x y)
    (if (equal? x y)
        (== sameness 'same)
        (== sameness 'different))))

(define (preserves-oneo expr op h1 h2)
  (fresh (s1 s2 o1 o2 summary-same obs-same)
    (summary-valueo expr h1 s1)
    (summary-valueo expr h2 s2)
    (observableo op h1 o1)
    (observableo op h2 o2)
    (same-groundo s1 s2 summary-same)
    (same-groundo o1 o2 obs-same)
    (conde
      [(== summary-same 'different)]
      [(== summary-same 'same) (== obs-same 'same)])))

(define (preserves-vocabo vocab expr h1 h2)
  (conde
    [(== vocab '())]
    [(fresh (op rest)
       (== `(,op . ,rest) vocab)
       (preserves-oneo expr op h1 h2)
       (preserves-vocabo rest expr h1 h2))]))

(define (sufficient-expressiono vocab size expr)
  (fresh ()
    (summary-expro size expr)
    ;; Six unordered pairs cover the four history classes from Observation 005.
    (preserves-vocabo vocab expr 'h00 'h10)
    (preserves-vocabo vocab expr 'h00 'h01)
    (preserves-vocabo vocab expr 'h00 'h11)
    (preserves-vocabo vocab expr 'h10 'h01)
    (preserves-vocabo vocab expr 'h10 'h11)
    (preserves-vocabo vocab expr 'h01 'h11)))

(define (summary-expressions vocabulary-name size)
  (run* (q)
    (fresh (ops)
      (vocabularyo vocabulary-name ops)
      (sufficient-expressiono ops size q))))

(define (same-answer-set? got expected)
  (and (= (length got) (length expected))
       (andmap (lambda (x) (member x expected equal?)) got)))

(define got-u0-one (summary-expressions 'u0-only 'one))
(define got-u1-one (summary-expressions 'u1-only 'one))
(define got-both-one (summary-expressions 'both 'one))
(define got-both-two (summary-expressions 'both 'two))

(define expected-u0-one '((observe u0)))
(define expected-u1-one '((observe u1)))
(define expected-both-one '())
(define expected-both-two
  '((combine (observe u0) (observe u1))
    (combine (observe u0) (observe count))
    (combine (observe u1) (observe count))))

(unless (same-answer-set? got-u0-one expected-u0-one)
  (error 'observation-007 "unexpected one-observer u0 summaries: ~s" got-u0-one))
(unless (same-answer-set? got-u1-one expected-u1-one)
  (error 'observation-007 "unexpected one-observer u1 summaries: ~s" got-u1-one))
(unless (same-answer-set? got-both-one expected-both-one)
  (error 'observation-007 "one observer unexpectedly preserves both: ~s" got-both-one))
(unless (same-answer-set? got-both-two expected-both-two)
  (error 'observation-007 "unexpected two-observer summaries: ~s" got-both-two))

(printf "OBSERVATION_007_OK\n")
(printf "u0-only / one observer: ~s\n" got-u0-one)
(printf "u1-only / one observer: ~s\n" got-u1-one)
(printf "both / one observer: ~s\n" got-both-one)
(printf "both / two observers: ~s\n" got-both-two)
