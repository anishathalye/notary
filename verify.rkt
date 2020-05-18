#lang rosette/safe

(require "soc.rkt"
         yosys/parameters
         shiva
         rosutil
         (only-in racket struct-copy)
         syntax/parse/define)

(overapproximate-symbolic-load-threshold 64)
(overapproximate-symbolic-store-threshold 64)

(define (input-setter s)
  (struct-copy soc_s s
                      [resetn #t]
                      [gpio_pin_in (bv 0 8)]
                      [uart_rx (bv #b1111 4)]))

(define (init-input-setter s)
  (struct-copy soc_s s
                      [resetn #f]
                      [gpio_pin_in (bv 0 8)]
                      [uart_rx (bv #b1111 4)]))

(define (statics s)
  ; for some reason, the picorv32 has a physical register for x0/zero,
  ; cpuregs[0], whose value can never change in practice
  (vector-ref (|soc_m cpu.cpuregs| s) 0))

(define-simple-macro (fresh-memory-like name mem)
  (let ([elem-type (type-of (vector-ref mem 0))])
    (list->vector
     (build-list (vector-length mem) (lambda (_) (fresh-symbolic name elem-type))))))

(define (overapproximate s cycle)
  (if (equal? cycle 4)
      ; overapproximate cpuregs behavior to avoid a big ite that doesn't matter
      (struct-copy soc_s s [cpu.cpuregs (fresh-memory-like cpuregs (|soc_m cpu.cpuregs| s))])
      ; leave it untouched on all cycles past the 1st
      #f))

(verify-deterministic-start
 soc_s
 new-symbolic-soc_s
 #:invariant soc_i
 #:step soc_t
 #:init-input-setter init-input-setter
 #:input-setter input-setter
 #:state-getters (append registers memories)
 #:statics statics
 #:overapproximate overapproximate
 #:print-style 'names
 #:try-verify-after 180340)
