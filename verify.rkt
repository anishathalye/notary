#lang racket/base

(require "soc.rkt"
         racket/match racket/cmdline racket/string racket/file racket/list
         (prefix-in @ (combine-in rosette rosutil))
         yosys shiva)

(@gc-terms!)

(define DEFAULT-TRY-VERIFY-AFTER 180340)
(define FAST-TRY-VERIFY-AFTER 100)

(overapproximate-symbolic-load-threshold 64)
(overapproximate-symbolic-store-threshold 64)

(define inputs-symbolic
  '(gpio_pin_in
    uart_rx))

(define inputs-default
  `((gpio_pin_in . ,(@bv 0 8))
    (uart_rx . ,(@bv #xf 4))))

(define statics
  ; for some reason, the picorv32 has a physical register for x0/zero,
  ; cpuregs[0], whose value can never change in practice
  '((cpu.cpuregs 0)))

(define raw-soc_i
  (let ([xs (file->lines "./hw/firmware.mem")])
    (map (lambda (line idx) `((rom.rom ,idx) . ,(@bv (string->number line 16) 32))) xs (range (length xs)))))

(define (hints-default q . args)
  (match q
    ['statics statics]
    [_ #f]))

(define abstract-command
  (let ([all-fields (fields (new-zeroed-soc_s))])
    (cons 'abstract (filter (lambda (f) (string-contains? (symbol->string f) "uart.recv_")) all-fields))))

(define (hints-symbolic q . args)
  (match q
    ['statics statics]
    ['general
     (match-define (list cycle sn) args)
     (cond
       [(zero? (modulo cycle 100)) (list abstract-command 'collect-garbage)]
       [else '#f])]))

(define start (make-parameter DEFAULT-TRY-VERIFY-AFTER))
(define limit (make-parameter #f))
(define exactly (make-parameter #f))
(define fast (make-parameter #f))
(define inputs (make-parameter inputs-default))
(define hints (make-parameter hints-default))
(define output-getters (make-parameter '()))

(command-line
 #:once-each
 [("-s" "--start") s
                   "Start invoking the SMT solver beyond this point"
                   (start (min (start) (string->number s)))]
 [("-l" "--limit") l
                   "Limit number of cycles to try"
                   (limit (string->number l))]
 [("-x" "--exactly") x
                     "Run for exactly this many cycles and then try to verify"
                     (exactly (string->number x))]
 [("-f" "--fast") "Skip verifying that RAM is cleared"
                  (fast #t)
                  (start (min (start) FAST-TRY-VERIFY-AFTER))]
 [("-i" "--inputs") "Analyze symbolic inputs"
                    (inputs inputs-symbolic)
                    (hints hints-symbolic)]
 [("-o" "--outputs") "Analyze outputs"
                     (output-getters outputs)])

(define state-getters
  (let ([all-getters (append registers memories)])
    (if (not (fast))
        all-getters
        (filter (match-lambda [(cons name _) (eq? name 'cpu.cpuregs)]) all-getters))))

(define cycles
  (verify-deterministic-start
   new-symbolic-soc_s
   #:invariant soc_i
   #:raw-invariant raw-soc_i
   #:step soc_t
   #:reset 'resetn
   #:reset-active 'low
   #:inputs (inputs)
   #:state-getters state-getters
   #:output-getters (output-getters)
   #:hints (hints)
   #:print-style 'names
   #:try-verify-after (or (exactly) (start))
   #:limit (or (exactly) (limit))))

(exit (if cycles 0 1))
