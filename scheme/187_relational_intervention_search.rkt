#lang racket

(require minikanren)

;; Observation 187 asks a genuinely backwards question:
;;
;;   given a required relief threshold, which small typed intervention bundles
;;   could satisfy it?
;;
;; The numbers below are deliberately synthetic units. They are not household
;; data and this program is not an accounting authority. miniKanren only
;; enumerates finite candidate bundles; a real candidate must still be replayed
;; through the qualified LOAM Application projection before it can answer a
;; household question.

;; action = (stable-order kind synthetic-relief protected?)
;;
;; Distinct kinds remain visible in every answer. Equal relief therefore does
;; not erase whether an intervention suppresses Scheduled evidence, reallocates
;; Capacity, changes a future consumption assumption, pauses a contribution, or
;; liquidates an asset.
(define (actiono action)
  (conde
    [(== action '(1 suppress-scheduled 2 #f))]
    [(== action '(2 suppress-scheduled 3 #f))]
    [(== action '(3 reallocate-capacity 4 #f))]
    [(== action '(4 reduce-consumption 5 #f))]
    [(== action '(5 pause-contribution 6 #f))]
    [(== action '(6 liquidate-asset 10 #t))]))

;; project is used only after actiono has grounded both synthetic order keys.
;; The relational work is choosing the unknown actions, not reimplementing LOAM
;; arithmetic over household evidence.
(define (ordered-beforeo left right)
  (project (left right)
    (== #t (< left right))))

(define (sum-groundo left right total)
  (project (left right)
    (== total (+ left right))))

(define (at-least-groundo relief threshold)
  (project (relief)
    (== #t (>= relief threshold))))

;; Search only singleton or two-action bundles in this first observation. The
;; stable order key removes duplicate permutations without pretending to find an
;; optimum.
(define (bundleo bundle relief)
  (conde
    [(fresh (a id-a kind-a relief-a protected-a)
       (actiono a)
       (== a `(,id-a ,kind-a ,relief-a ,protected-a))
       (== bundle `(,a))
       (== relief relief-a))]
    [(fresh (a b
             id-a kind-a relief-a protected-a
             id-b kind-b relief-b protected-b)
       (actiono a)
       (actiono b)
       (== a `(,id-a ,kind-a ,relief-a ,protected-a))
       (== b `(,id-b ,kind-b ,relief-b ,protected-b))
       (ordered-beforeo id-a id-b)
       (== bundle `(,a ,b))
       (sum-groundo relief-a relief-b relief))]))

(define (all-unprotectedo bundle)
  (conde
    [(== bundle '())]
    [(fresh (action rest id kind relief protected)
       (== `(,action . ,rest) bundle)
       (== action `(,id ,kind ,relief ,protected))
       (== protected #f)
       (all-unprotectedo rest))]))

;; policy is itself queryable provenance. `allow-protected` enumerates the whole
;; finite search space; `protect` rejects any bundle containing a candidate the
;; caller marked protected.
(define (feasibleo threshold policy bundle relief)
  (fresh ()
    (bundleo bundle relief)
    (at-least-groundo relief threshold)
    (conde
      [(== policy 'allow-protected)]
      [(== policy 'protect)
       (all-unprotectedo bundle)])))

(define (answers threshold policy)
  (run* (q)
    (fresh (bundle relief)
      (feasibleo threshold policy bundle relief)
      (== q `(,bundle ,relief)))))

(define all-answers (answers 10 'allow-protected))
(define protected-answers (answers 10 'protect))

(define expected-protected-a
  '(((3 reallocate-capacity 4 #f)
     (5 pause-contribution 6 #f))
    10))
(define expected-protected-b
  '(((4 reduce-consumption 5 #f)
     (5 pause-contribution 6 #f))
    11))

;; Keep qualification structural rather than depending on miniKanren's fair
;; interleaving order.
(unless (= (length all-answers) 8)
  (error 'observation-187 "unexpected all-candidate count: ~s" all-answers))
(unless (= (length protected-answers) 2)
  (error 'observation-187 "unexpected protected-candidate count: ~s" protected-answers))
(unless (member expected-protected-a protected-answers)
  (error 'observation-187 "missing protected candidate A: ~s" protected-answers))
(unless (member expected-protected-b protected-answers)
  (error 'observation-187 "missing protected candidate B: ~s" protected-answers))
(unless (member '(((6 liquidate-asset 10 #t)) 10) all-answers)
  (error 'observation-187 "whole search did not expose protected singleton"))
(unless (not (member '(((6 liquidate-asset 10 #t)) 10) protected-answers))
  (error 'observation-187 "protected singleton leaked through protection policy"))

(printf "OBSERVATION_187_OK\n")
(printf "all feasible bundles at synthetic threshold 10: ~s\n" all-answers)
(printf "feasible bundles with protected candidates excluded: ~s\n" protected-answers)
