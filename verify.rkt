#lang rosette/safe

(require "soc.rkt"
         yosys/parameters
         shiva
         rosutil
         (only-in racket struct-copy make-parameter string->number exit)
         (only-in racket/cmdline command-line)
         syntax/parse/define)

(define DEFAULT-TRY-VERIFY-AFTER 180340)

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

(define start (make-parameter DEFAULT-TRY-VERIFY-AFTER))
(define limit (make-parameter #f))
(define exactly (make-parameter #f))

(command-line
 #:program "verify"
 #:once-each
 [("-s" "--start") s
                   "Start invoking the SMT solver beyond this point"
                   (start (string->number s))]
 [("-l" "--limit") l
                   "Limit number of cycles to try"
                   (limit (string->number l))]
 [("-x" "--exactly") x
                     "Run for exactly this many cycles and then try to verify"
                     (exactly (string->number x))])

(define cycles
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
   #:try-verify-after (or (exactly) (start))
   #:limit (or (exactly) (limit))))

(exit (if cycles 0 1))
