#lang racket

(require minikanren)

;; Observation 006 asks whether a sufficient retained-state summary can be
;; searched from a small future operation vocabulary instead of proposed by hand.
;;
;; The four histories are the observable classes witnessed by Observation 005.
;; Their booleans mean whether U0 / U1 stayed continuously at Target.

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

;; Candidate summary grammar, deliberately ordered from coarser to richer.
;; This is finite candidate search, not synthesis over arbitrary programs.
(define (summary-kindo kind)
  (conde
    [(== kind 'constant)]
    [(== kind 'u0)]
    [(== kind 'u1)]
    [(== kind 'count)]
    [(== kind 'pair)]))

(define (summary-valueo kind h value)
  (fresh (u0 u1)
    (history-obso h u0 u1)
    (conde
      [(== kind 'constant)
       (== value 'same)]
      [(== kind 'u0)
       (== value u0)]
      [(== kind 'u1)
       (== value u1)]
      [(== kind 'count)
       (conde
         [(== u0 #f) (== u1 #f) (== value 'zero)]
         [(== u0 #t) (== u1 #f) (== value 'one)]
         [(== u0 #f) (== u1 #t) (== value 'one)]
         [(== u0 #t) (== u1 #t) (== value 'two)])]
      [(== kind 'pair)
       (== value `(,u0 ,u1))])))

(define (observableo op h value)
  (fresh (u0 u1)
    (history-obso h u0 u1)
    (conde
      [(== op 'u0) (== value u0)]
      [(== op 'u1) (== value u1)])))

;; project is used only after the finite history/kind relations have grounded
;; both terms. The outer search over vocabulary and summary kind remains relational.
(define (same-groundo x y sameness)
  (project (x y)
    (if (equal? x y)
        (== sameness 'same)
        (== sameness 'different))))

;; A summary is sufficient for one operation on one pair of histories when
;; collapsing the histories in the summary never hides an operation-visible
;; distinction.
(define (preserves-oneo kind op h1 h2)
  (fresh (s1 s2 o1 o2 summary-same obs-same)
    (summary-valueo kind h1 s1)
    (summary-valueo kind h2 s2)
    (observableo op h1 o1)
    (observableo op h2 o2)
    (same-groundo s1 s2 summary-same)
    (same-groundo o1 o2 obs-same)
    (conde
      [(== summary-same 'different)]
      [(== summary-same 'same) (== obs-same 'same)])))

(define (preserves-vocabo vocab kind h1 h2)
  (conde
    [(== vocab '())]
    [(fresh (op rest)
       (== `(,op . ,rest) vocab)
       (preserves-oneo kind op h1 h2)
       (preserves-vocabo rest kind h1 h2))]))

(define (sufficient-summaryo vocab kind)
  (summary-kindo kind)
  ;; Six unordered pairs cover the four history classes.
  (preserves-vocabo vocab kind 'h00 'h10)
  (preserves-vocabo vocab kind 'h00 'h01)
  (preserves-vocabo vocab kind 'h00 'h11)
  (preserves-vocabo vocab kind 'h10 'h01)
  (preserves-vocabo vocab kind 'h10 'h11)
  (preserves-vocabo vocab kind 'h01 'h11))

(define (summary-answers vocabulary-name)
  (run* (q)
    (fresh (ops)
      (vocabularyo vocabulary-name ops)
      (sufficient-summaryo ops q))))

(define (vocabularies-preserved-by summary-kind)
  (run* (q)
    (fresh (ops)
      (vocabularyo q ops)
      (sufficient-summaryo ops summary-kind))))

(define expected-u0 '(u0 pair))
(define expected-u1 '(u1 pair))
(define expected-both '(pair))
(define expected-none '(constant u0 u1 count pair))

(define got-u0 (summary-answers 'u0-only))
(define got-u1 (summary-answers 'u1-only))
(define got-both (summary-answers 'both))
(define got-none (summary-answers 'none))

(unless (equal? got-u0 expected-u0)
  (error 'observation-006 "unexpected u0-only summaries: ~s" got-u0))
(unless (equal? got-u1 expected-u1)
  (error 'observation-006 "unexpected u1-only summaries: ~s" got-u1))
(unless (equal? got-both expected-both)
  (error 'observation-006 "unexpected two-operation summaries: ~s" got-both))
(unless (equal? got-none expected-none)
  (error 'observation-006 "unexpected empty-vocabulary summaries: ~s" got-none))

;; Reverse query: ask which future vocabularies a proposed summary can preserve.
(define count-vocabularies (vocabularies-preserved-by 'count))
(define u0-vocabularies (vocabularies-preserved-by 'u0))

(unless (equal? count-vocabularies '(none))
  (error 'observation-006 "count unexpectedly preserves: ~s" count-vocabularies))
(unless (equal? u0-vocabularies '(none u0-only))
  (error 'observation-006 "u0 unexpectedly preserves: ~s" u0-vocabularies))

(printf "OBSERVATION_006_OK\n")
(printf "u0-only sufficient summaries: ~s\n" got-u0)
(printf "u1-only sufficient summaries: ~s\n" got-u1)
(printf "both sufficient summaries: ~s\n" got-both)
(printf "count preserves vocabularies: ~s\n" count-vocabularies)
(printf "u0 preserves vocabularies: ~s\n" u0-vocabularies)
