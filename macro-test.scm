;; A temporary testbed file
(import (scheme base)
        (scheme eval)
        ;(scheme file)
        ;(scheme read)
        (scheme write)
        (scheme cyclone common)
        (scheme cyclone util)
        ;(scheme cyclone cgen)
        (scheme cyclone transforms)
        (scheme cyclone macros)
        ;(scheme cyclone libraries)
        )

;(define input-program '(lambda (x) (begin (+ x x) 1 2 3)))
(define input-program 
  '((lambda ()
    (define-syntax test
      (er-macro-transformer
       (lambda (expr rename compare)
         `(begin 1 (define tmp #t) 3))))
    (test)
    (test)
    (write tmp)
    )))

      ;; Load macros for expansion phase
      (let ((macros (filter 
                      (lambda (v) 
                        (macro? (Cyc-get-cvar (cdr v))))
                      (Cyc-global-vars))))
        (set! *defined-macros*
              (append
                macros
                *defined-macros*)))
      (macro:load-env! *defined-macros* (create-environment '() '()))

      ;; Expand macros
      (set! input-program (my-expand input-program (macro:get-env)))
      (write "---------------- after macro expansion:")
      (write input-program) ;pretty-print

;; A first step towards splicing begin, but this doesn't handle
;; begin being introduced as part of a macro
(define (expand-body result exp env)
  (cond
   ((null? exp) (reverse result))
   ((begin? (car exp))
    (let* ((expr (car exp))
           (begin-exprs (begin->exps expr))
           (expanded-exprs (map (lambda (expr) (my-expand expr env)) begin-exprs)))
    (expand-body
     (append result (reverse expanded-exprs))
     (cdr exp)
     env)))
   (else
     (expand-body
      (cons 
        (my-expand (car exp) env)
        result)
      (cdr exp)
      env))))

(define (my-expand exp env)
  (inner-expand exp env #f))

;; TODO: replace my-expand's below (and above in expand-body) with inner-expand. still trying to figure out how to use body? arg though.
;; TODO: need to be able to splice expanded begins somehow.
;; maybe pass built up exp list to it and splice the begin into that before
;; continuing expansion
(define (inner-expand exp env body?)
  (cond
    ((const? exp)      exp)
    ((prim? exp)       exp)
    ((ref? exp)        exp)
    ((quote? exp)      exp)
;; TODO: need a way of taking a begin here and splicing its contents
;; into the body
    ((lambda? exp)     `(lambda ,(lambda->formals exp)
                          ,@(expand-body '() (lambda->exp exp) env)
                          ;,@(map 
                          ;  ;; TODO: use extend env here?
                          ;  (lambda (expr) (my-expand expr env))
                          ;  (lambda->exp exp))
                        ))
    ((define? exp)     (if (define-lambda? exp)
                           (my-expand (define->lambda exp) env)
                          `(define ,(my-expand (define->var exp) env)
                                ,@(my-expand (define->exp exp) env))))
    ((set!? exp)       `(set! ,(my-expand (set!->var exp) env)
                              ,(my-expand (set!->exp exp) env)))
    ((if? exp)         `(if ,(my-expand (if->condition exp) env)
                            ,(my-expand (if->then exp) env)
                            ,(if (if-else? exp)
                                 (my-expand (if->else exp) env)
                                 ;; Insert default value for missing else clause
                                 ;; FUTURE: append the empty (unprinted) value
                                 ;; instead of #f
                                 #f)))
    ((app? exp)
     (cond
     ((define-syntax? exp)
      (let* ((name (cadr exp))
             (trans (caddr exp))
             (body (cadr trans)))
        (set! *defined-macros* (cons (cons name body) *defined-macros*))
        (macro:add! name body)
        (env:define-variable! name (list 'macro body) env)
        `(define ,name ,(expand body env))))
     ((symbol? (car exp))
      (let ((val (env:lookup (car exp) env #f)))
        (if (tagged-list? 'macro val)
          (my-expand ; Could expand into another macro
            (macro:expand exp val env)
            env)
          (map
            (lambda (expr) (my-expand expr env))
            exp))))

     (else
       (map 
        (lambda (expr) (my-expand expr env))
        exp))))
    (else
      (error "unknown exp: " exp))))