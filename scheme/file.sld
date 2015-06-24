(define-library (scheme file)
  (export
    call-with-input-file 
    call-with-output-file
    ;delete-file 
    ;file-exists?
    ;open-binary-input-file 
    ;open-binary-output-file
    ;open-input-file 
    ;open-output-file
    with-input-from-file 
    with-output-to-file
  )
  (import (scheme base))
  (begin
    (define (call-with-input-file string proc)
      (call-with-port (open-input-file string) proc))
    (define (call-with-output-file string proc)
      (call-with-port (open-output-file string) proc))
    (define (with-input-from-file string thunk) #f)
    (define (with-output-to-file string thunk)
      ;; Have to do this the long way since parameterize is not available
      (let ((old (current-output-port))
            (new (current-output-port '<param-convert> (open-output-file string))))
        (dynamic-wind
          (lambda () (current-output-port '<param-set!> new))
          thunk
          (lambda () 
            (close-port (current-output-port))
            (current-output-port '<param-set!> old)))))
))