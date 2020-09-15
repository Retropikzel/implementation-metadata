#! /usr/bin/env gosh

(import (scheme base) (scheme char) (scheme file)
        (scheme read) (scheme write))
(import (srfi 1) (srfi 13) (srfi 132) (srfi 193))
(import (gauche base) (sxml serializer))
(import (srfi 69))

(define (disp . xs) (for-each display xs) (newline))
(define (writeln x) (write x) (newline))
(define (assoc? key alist) (cdr (or (assoc key alist) '(#f #f))))

(define data (with-input-from-file "repology-data.scm" read))

(define project-repo-names (make-hash-table equal?))

(define implementations
  (for-each (lambda (project-data)
              (let ((project (car project-data)))
                (cons project
                      (for-each (lambda (x)
                                  (let ((repo (assoc? "repo" x))
                                        (name (assoc? "visiblename" x)))
                                    (hash-table-update!/default
                                     project-repo-names
                                     project
                                     (lambda (repo-names)
                                       (hash-table-set! repo-names
                                                        repo
                                                        name)
                                       repo-names)
                                     (make-hash-table equal?))))
                                (vector->list (cdr project-data))))))
            data))

(define projects
  (list-sort string-ci<?
             (hash-table-keys project-repo-names)))

(define repos
  (list-delete-neighbor-dups
   string=?
   (list-sort
    string-ci<?
    (hash-table-fold project-repo-names
                     (lambda (project repo-names repos)
                       (let ((project-repos (hash-table-keys repo-names)))
                         (append repos project-repos)))
                     '()))))

(define (project-repo-name project repo)
  (let ((names (hash-table-ref project-repo-names project)))
    (hash-table-ref/default names repo #f)))

(define (generate-sxml)
  (define (pkg-tds pkg)
    `((td ,(list-ref pkg 0))
      (td ,(list-ref pkg 1))))
  `(html
    (head
     (title "Repology data")
     (style ,(string-append
              "table, td, th { border: 1px solid black; }"
              "td { vertical-align: top }")))
    (body
     (h1 "Repology data")
     (table
      (tr (th "")
          ,@(map (lambda (project) `(th ,project))
                 projects))
      ,@(map (lambda (repo)
               `(tr (td ,repo)
                    ,@(map (lambda (project)
                             `(td ,(or (project-repo-name project repo)
                                       "")))
                           projects)))
             repos)))))

(let ((sxml (generate-sxml)))
  (with-output-to-file "repology-data.html"
    (lambda () (srl:sxml->html sxml (current-output-port)))))
