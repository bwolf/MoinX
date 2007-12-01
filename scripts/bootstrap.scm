#! /usr/bin/env mzscheme -qr
#|

Copyright: 2007 Marcus Geiger <moinx@antbear.org> for bootstrapping MoinX.

Created on Wed Jun 21 17:52:25 CEST 2006.
Updated on Sat 1 Dec 2007 16:43:38 CET.

You need PLTs `mzscheme' to process this file (http://www.plt-scheme.org/).

Tested mzscheme versions are (mzscheme -v):
Welcome to MzScheme version 350, Copyright (c) 2004-2006 PLT Scheme Inc.

NOTES:
 0) create a common directory for the required 3rd party packages
 1) download MoinMoin and place it into the common dir
 2) download Twisted and place it into the common dir
 3) download libarchive and place it into the common dir
 4) ensure that you use only tested releases 3rd party packages
 5) edit the user configuration section (see below)
 6) run this script from the project base directory
 7) keep in mind, that this script is modified according to the
    3rd party package version. Thus it may not work with older
    or newer releases of them

DOWNLOAD URLS
 a) MoinMoin:   http://moinmo.in/
 b) Twisted:    http://twistedmatrix.com/
 c) libarchive: http://people.freebsd.org/~kientzle/libarchive/

TESTED PRODUCT VERSIONs
  I) MoinMoin:   1.3.1, 1.3.3, 1.3.5, 1.5.3, 1.5.8
 II) Twisted:    1.3.0, 2.4.0, 2.5.0
III) libarchive: 1.01.022, 1.02.002, 1.02.030, 1.2.53, 2.4.0 

|#

(require (lib "process.ss"))
(require (lib "file.ss"))
(require (lib "list.ss"))
(require (lib "kw.ss"))
(require (lib "string.ss" "srfi" "13"))

;;; -------------------------------------------------------------------
;;; BEGIN USER CONFIGURATION SECTION
;; Base directory for distribution files.
(define user-config/dist-base
  "/Users/bwolf/Desktop/distfiles/")
(define user-config/moin-basename "moin-1.5.8.tar.gz")
(define user-config/moin-version "moin-1.5.8")
(define user-config/twisted-basename "Twisted-2.5.0.tar.bz2")
(define user-config/twisted-version "Twisted-2.5.0")
(define user-config/twisted-zope-interface-version "zope.interface-3.3.0")
(define user-config/twisted-core-version "TwistedCore-2.5.0")
(define user-config/twisted-web-version "TwistedWeb-0.7.0")
(define user-config/libarchive-basename "libarchive-2.4.0.tar.gz")
(define user-config/libarchive-version "libarchive-2.4.0")
;;; END USER CONFIGURATION SECTION
;;; -------------------------------------------------------------------

;;; -------------------------------------------------------------------
;;; BEGIN NOT SO OFTEN CHANGED CONFIGURATION
(define verbose-enabled #f)
(define universal-binary-cflags
  "-isysroot /Developer/SDKs/MacOSX10.4u.sdk -arch ppc -arch i386 -mmacosx-version-min=10.4")
(define universal-binary-configure-args '("--disable-dependency-tracking"))
;;; END NOT SO OFTEN CHANGED CONFIGURATION
;;; -------------------------------------------------------------------

;; Build pathes out of the user supplied configuration (see above).
;; Note: the variables `user-config/*' are not used directly.
(define dist-base (string->path user-config/dist-base))
(define dist-moin (build-path dist-base user-config/moin-basename))
(define moin-release user-config/moin-version)
(define dist-twisted (build-path dist-base user-config/twisted-basename))
(define twisted-release user-config/twisted-version)
(define twisted-zope-interface-release user-config/twisted-zope-interface-version)
(define twisted-core-release user-config/twisted-core-version)
(define twisted-web-release user-config/twisted-web-version)
(define dist-libarchive (build-path dist-base user-config/libarchive-basename))
(define libarchive-release user-config/libarchive-version)

;;; -------------------------------------------------------------------
;;; Utilities.
;;; -------------------------------------------------------------------

;; Logging (see `verbose-enabled').
(define (log fmt . rest)
  (when verbose-enabled
    (apply printf `(,fmt ,@rest))))

(define (echo fmt . rest)
  (apply printf `(,fmt ,@rest)))

(define (fail fmt . rest)
  (error (apply format `(,(string-append fmt "~%") ,@rest))))

(define (remove-directories dir-list)
  (for-each (lambda (d)
              (echo "cleaning up ~a~%" d)
              (when (or (file-exists? d) (directory-exists? d))
                (delete-directory/files d)))
            dir-list))

(define (make-directories dir-list)
  (for-each (lambda (d)
              (log "mkdir ~a~%" d)
              (unless (directory-exists? d)
                (make-directory d)))
            dir-list))

;; system/output : string -> (U string #f)
;;
;; Synchronously run the given command through the shell and
;; capture standard output.
;;
;; Returns the standard output or #f if the command failed
;;
;; If the command blocks for any reason (e.g. waiting for
;; input) this function will as well.
(define (system/output command-string)
  (let ([p (open-output-string)])
    (parameterize ([current-output-port p])
      (if (system command-string)
          (get-output-string p)
          #f))))

;; expects an path argument, not a string
(define (extract-archive file-path)
  (let* ((file (path->string (file-name-from-path file-path)))
         (args (cond ((string-suffix? ".tar.bz2" file) "xfj")
                     ((string-suffix? ".tar.gz" file) "xfz")
                     ((string-suffix? ".tgz" file) "xfz")
                     ((string-suffix? ".tar" file) "xf")
                     (else (fail "Given archive file has an unknown suffix.")))))
    (echo "extracting (~a) ~a~%" args file-path)
    (unless (system (format "tar ~a ~a" args file-path))
      (fail "Failed to extract archive file ~a" file-path))))

(define-syntax with-cwd
  (syntax-rules ()
    ((with-cwd dir body ...)
     (let ((prev-dir (current-directory)))
       (current-directory dir)
       (log "Changed directory to ~a (~a)~%"
            dir
            (equal? (current-directory) dir))
       (let ((result (begin
                       body ...)))
         (current-directory prev-dir)
         (log "Result of body is ~a; Changed directory back to ~a~%" result prev-dir)
         result)))))

(define-syntax with-env
  (syntax-rules ()
    ((with-env env-alist body ...)
     (let ((preserved-environment 
            (let loop ((env env-alist)
                       (preserve-alist '()))
              (if (null? env)
                  preserve-alist
                  (let* ((cell (car env)) ; (var . val)
                         (var (car cell))
                         (val (getenv var))) ; #f if undef
                    (loop (cdr env)
                          (cons `(,var . ,val)
                                preserve-alist)))))))
       (log "preserving environment '~a~%" preserved-environment)
       (let loop ((env env-alist))
         (unless (null? env)
           (let ((cell (car env)))
             (log "setting environment ~a -> ~a~%" (car cell) (cdr cell))
             (putenv (car cell) (cdr cell)))
           (loop (cdr env))))
       body ...
       (let loop ((env preserved-environment))
         (unless (null? env)
           (let* ((cell (car env))
                  (var (car cell))
                  (val (cdr cell)))
             (log "resetting environment ~a -> ~a~%" (car cell) (cdr cell))
             (if val
                 (putenv var val)
                 (putenv var ""))
           (loop (cdr env)))))))))

(define/kw (run-python-install name build-dir source-dir install-log
                               #:key quiet silent-stdout)
  (let ((source-dir-s (path->string source-dir))
        (install-log-s (path->string install-log))
        (build-dir-s (path->string build-dir)))
    (echo "*** building ~a in ~a~%" name source-dir-s)
    (echo "... installation logfile in ~a~%" install-log-s)
    (echo "... install dir is ~a~%" build-dir-s)
    (with-cwd source-dir
              (unless (system
                       (let ((cmd (format
                                   (string-append "python setup.py ~ainstall "
                                                  "--prefix=~a --record=~a")
                                   (if quiet "--quiet " "")
                                   build-dir-s
                                   install-log-s)))
                         (if silent-stdout
                             (string-append cmd ">/dev/null")
                             cmd)))
                (fail "Failed to build ~a" name))))
    (newline))

(define/kw (run-make-c-package name action-name build-dir source-dir log-file fmt
                               #:key args (env-alist '()))
  (echo "*** ~a ~a in ~a~%" action-name name (path->string source-dir))
  (echo "... ~a logfile in ~a~%" action-name (path->string log-file))
  (echo "... installation dir is ~a~%" (path->string build-dir))
  (echo "... -> running ~a~%" action-name)
  (with-cwd source-dir
            (with-env env-alist
                      (unless (system (apply format fmt args))
                        (fail "Failed to run ~a" action-name))))
  (newline))

(define (copy-preserve src dst)
  (let ((src-s (path->string src))
        (dst-s (path->string dst)))
    (echo "cp -p ~a ~a~%" src-s dst-s)
    (unless (system (format "cp -p ~a ~a" src-s dst-s))
      (fail "Failed to cp -p ~a ~a" src-s dst-s))))

(define (copy-recursive src dst)
  (let ((src-s (path->string src))
        (dst-s (path->string dst)))
    (echo "cp -Rp ~a ~a~%" src-s dst-s)
    (unless (system (format "cp -Rp ~a ~a" src-s dst-s))
      (fail "Failed to cp -Rp ~a ~a" src-s dst-s))))

(define (make-tar/bz2 archive-fname src)
  (let ((fname (path->string archive-fname))
        (src-s (path->string src)))
    (echo "tar cfj ~a ~a~%" fname src-s)
    (unless (system (format "tar cfj ~a ~a~%" fname src-s))
      (fail "Failed to tar cfj ~a ~a" fname src-s))))

(define (shrink-directory dir-path shrink-file-name)
  (with-cwd dir-path
    (echo "In directory ~a~%" (current-directory))
    (with-input-from-file (path->string shrink-file-name)
      (lambda ()
        (let ((next-file
               (lambda ()
                 (read-line (current-input-port) 'any))))
          (let loop ((fname (next-file)))
            (unless (eof-object? fname)
              (cond ((zero? (string-length fname))
                     (log "Skipping empty line~%"))
                    ((char=? (string-ref fname 0) #\#)
                     (log "Skipping comment line ~a~%" fname))
                    ((or (file-exists? fname) (directory-exists? fname))
                     (echo " - ~a~%" fname)
                     (delete-directory/files fname)))
              (loop (next-file)))))))))

(define (string-list->string-with-spc string-list)
  (let loop ((tail string-list)
             (acc ""))
    (if (null? tail)
        acc
        (loop (cdr tail)
              (let ((acc-tmp
                     (if (> (string-length acc) 0)
                         (string-append acc " ")
                         acc)))
                (string-append acc-tmp (car tail)))))))

(define (make-zip archive-fname base-dir . dirs)
  (with-cwd base-dir
    (echo "In directory ~a~%" (current-directory))
    (when (file-exists? archive-fname)
      (echo "Removing existing archive ~a~%" archive-fname)
      (delete-directory/files archive-fname))
    (let ((cmd (format "zip -rq9T ~a ~a"
                       archive-fname
                       (string-list->string-with-spc dirs))))
      (echo "~a~%" cmd)
      (unless (system cmd)
        (fail "Failed to ~a" cmd)))))

(define (delete-directory/files-ext dir ext)
  (let ((bytes-ext (string->bytes/locale ext)))
    (let loop ((tail (directory-list dir)))
      (unless (null? tail)
        (let* ((path-name (car tail))
               (abs-fname (build-path dir path-name)))
          (when (or (file-exists? abs-fname) 
                    (link-exists? abs-fname))
            ;(printf "~a~%" abs-fname)
            (let ((file-ext (filename-extension abs-fname)))
              (when (bytes=? file-ext bytes-ext)
                (printf " -~a~%" abs-fname)
                (delete-file abs-fname)))))
        (loop (cdr tail))))))

(define (directory->list dir)
  (with-cwd dir
    (sort
     (fold-files
      (lambda (path-name type acc)
        (if (eq? type 'dir)
            (cons path-name acc)
            acc))
      '())
     (lambda (a b)
       (string<? (path->string a)
                 (path->string b))))))

(define (replicate-directory-tree src-dir dst-dir)
  (with-cwd dst-dir
    (let loop ((dirs (directory->list src-dir)))
      (unless (null? dirs)
        (log "make-directory ~a~%" (car dirs))
        (make-directory (car dirs))
        (loop (cdr dirs))))))

;;; -------------------------------------------------------------------
;;; Define some useful variables.
;;; -------------------------------------------------------------------

(define dist-files (list dist-moin dist-twisted dist-libarchive))

(for-each
 (lambda (fn)
   (unless (file-exists? fn)
     (fail "Required file ~a is missing.~%Check you configuration." fn)))
 dist-files)

;; Ensure the current Directory contains a subdirectory Named MoinX.xcode
;; such that the script called from the project base directory.
(unless (directory-exists? (string->path "MoinX.xcodeproj"))
  (fail "Script must be called from the project root directory"))

;; We now define a set of variables which simplify path construction.
(define base (current-directory))
(define generated (build-path base "generated"))
(define build-dir (build-path generated "build"))
(define src-dir (build-path build-dir "src"))
(define out-dir (build-path generated "WikiBootstrap"))
(define log-dir (build-path build-dir "log"))

;; MoinX stuff.
(define instance-name "instance")
(define instance-default (build-path out-dir instance-name))
(define instance-default-archive
  (build-path out-dir (string-append instance-name ".tar.bz2")))
(define bin-dir (build-path out-dir "bin"))
(define python-lib-dir (build-path out-dir "pythonlib"))
(define python-aux-lib-dir (build-path out-dir "pythonlib-aux"))
(define python-aux-lib-dir-readme (build-path base "scripts/README.python"))

(define htdocs-dir out-dir) ; source directory is a htdocs dir
(define python-run-dir (build-path out-dir "pyrun"))

;; Moin stuff.
(define moin-source (build-path src-dir moin-release))
(define moin-install-log (build-path log-dir "moin-install.log"))
(define moin-base-dir (build-path build-dir "share/moin"))
(define moin-license (build-path moin-source "docs/licenses/COPYING"))

;; Generic.
(define python-version
  (string-trim-right
   (system/output (string-append "python -c 'import sys; print \"%d.%d\" % "
                                 "(sys.version_info[0],sys.version_info[1])'"))))

(define python-local-packages-install-dir (build-path
                                           (build-path
                                            (build-path build-dir "lib")
                                            (format "python~a" python-version))
                                           "site-packages"))

;; Twisted stuff.
(define twisted-source (build-path src-dir twisted-release))
(define twisted-license (build-path twisted-source "LICENSE"))
(define twisted-zope-interface-source
  (build-path twisted-source twisted-zope-interface-release))
(define twisted-zope-interface-install-log
  (build-path log-dir "twisted-zope-interface-install.log"))
(define twisted-core-source (build-path twisted-source twisted-core-release))
(define twisted-core-install-log (build-path log-dir "twisted-core-install.log"))
(define twisted-web-source (build-path twisted-source twisted-web-release))
(define twisted-web-install-log (build-path log-dir "twisted-web-install.log"))

;; libarchive stuff.
(define libarchive-source (build-path src-dir libarchive-release))
(define libarchive-license (build-path libarchive-source "COPYING"))
(define libarchive-configure-log (build-path log-dir "libarchive-configure.log"))
(define libarchive-make-log (build-path log-dir "libarchive-make.log"))
(define libarchive-make-install-log (build-path log-dir "libarchive-make-install.log"))

;; shrink files.
(define zope-shrink-file (build-path base "scripts/zope-shrink-file.txt"))
(define twisted-shrink-file (build-path base "scripts/twisted-shrink-file.txt"))
(define moinmoin-shrink-file (build-path base "scripts/moinmoin-shrink-file.txt"))

;; ---------------------------------------------------------------------
;; Prepare
;; ---------------------------------------------------------------------

;; Ensure generated files have sane umask.
;; (set-umask 027)

(echo "*** cleaning up possible pre existing build hierachy~%")
(remove-directories (list generated
                          build-dir
                          out-dir))
(newline)

(echo "*** creating build infrastructure...~%")
(make-directories (list generated
                        build-dir
                        src-dir
                        out-dir
                        log-dir
                        bin-dir
                        python-lib-dir
                        python-aux-lib-dir
                        htdocs-dir
                        python-run-dir
                        instance-default))
(newline)

(putenv "DYLD_FALLBACK_LIBRARY_PATH" "") ; for safety
(putenv "PYTHONPATH" (path->string python-local-packages-install-dir))
(echo "*** set environment~%")
(echo "... Python version is '~a'~%" python-version)
(echo "... PYTHONPATH is ~a~%" (getenv "PYTHONPATH"))
(newline)

(echo "*** unpacking distribution files...~%")
(with-cwd src-dir
          (for-each extract-archive dist-files))
(newline)

(echo "*** patching sources...~%")
(let* ((patch-dir (build-path base "patches"))
       (patches (with-cwd patch-dir
                              (find-files (lambda (x) #t) #f))))
  (for-each (lambda (patch-file)
              (echo "with ~a~%" patch-file)
              (let ((cmd (format "pwd; patch -p1 < \"~a\"" 
                                 (build-path patch-dir patch-file))))
                (with-cwd src-dir
                          (unless (system cmd)
                            (fail "Failed to ~a" cmd)))))
            patches))
(newline)

;;; -------------------------------------------------------------------
;;; Build
;;; -------------------------------------------------------------------

(run-python-install "moin"
                    build-dir
                    moin-source
                    moin-install-log
                    #:quiet #t
                    #:silent-stdout #f)

(run-python-install "twisted/zope-interface"
                    build-dir
                    twisted-zope-interface-source
                    twisted-zope-interface-install-log
                    #:quiet #t
                    #:silent-stdout #f)

(run-python-install "twisted/core"
                    build-dir
                    twisted-core-source
                    twisted-core-install-log
                    #:quiet #f
                    #:silent-stdout #t)

(run-python-install "twisted/web"
                    build-dir
                    twisted-web-source
                    twisted-web-install-log
                    #:quiet #f
                    #:silent-stdout #t)

(run-make-c-package "libarchive"
                    "configure"
                    build-dir
                    libarchive-source
                    libarchive-configure-log
                    (string-append "./configure "
                                   "--prefix ~a ~a >~a")
                    #:args (list build-dir
                                 (string-list->string-with-spc
                                  universal-binary-configure-args)
                                 libarchive-configure-log)
                    #:env-alist `(("CFLAGS" . ,universal-binary-cflags)))

(run-make-c-package "libarchive"
                    "make"
                    build-dir
                    libarchive-source
                    libarchive-make-log
                    "make >~a"
                    #:args '("/dev/null"))

(run-make-c-package "libarchive"
                    "make install"
                    build-dir
                    libarchive-source
                    libarchive-make-install-log
                    "make install >~a"
                    #:args '("/dev/null"))

;;; -------------------------------------------------------------------
;;; Assemble
;;; -------------------------------------------------------------------

(echo "*** assemblying~%")
(with-cwd generated
          (copy-preserve (build-path build-dir "bin/twistd") bin-dir)
          (copy-recursive (build-path python-local-packages-install-dir "*") python-lib-dir)
          (copy-recursive (build-path build-dir "share/moin/htdocs") htdocs-dir))
(with-cwd base
          (copy-recursive (string->path "python/*.py") python-run-dir)
          (copy-recursive (build-path build-dir "share/moin/data") instance-default)
          (copy-recursive (build-path build-dir "share/moin/underlay") instance-default))
(with-cwd out-dir
          (make-tar/bz2 (file-name-from-path instance-default-archive)
                        (file-name-from-path instance-name))
          (remove-directories `(,instance-name))
          (copy-preserve moin-license (build-path out-dir "LICENSE.MoinMoin"))
          (copy-preserve twisted-license (build-path out-dir "LICENSE.Twisted"))
          (copy-preserve libarchive-license (build-path out-dir "COPYING.libarchive")))

;; remove everything except *.lib, because xcode prefers *.dylib regardless
;; of what was added to `Frameworks'.
(delete-directory/files-ext (build-path build-dir "lib") "dylib")

(with-cwd base
          (unless (system
                   (format "tiffutil -cat Icons/MoinX_16.tif -out ~a"
                           (path->string (build-path base "MoinX_statusmenuicon.tif"))))
            (fail "Failed to build MoinX statusmenu icon")))

(echo "*** shrinking~%")
(shrink-directory (build-path python-lib-dir "zope")
                  zope-shrink-file)
(shrink-directory (build-path python-lib-dir "twisted")
                  twisted-shrink-file)
(shrink-directory (build-path python-lib-dir "MoinMoin")
                  moinmoin-shrink-file)
(newline)

(echo "*** creating zip out of pythonlib~%")
(make-zip (build-path out-dir "pythonlib.zip") python-lib-dir "zope" "twisted" "MoinMoin")
(newline)

(echo "*** duplicating moinmoin pythonlib hierarchy in ~a~%" python-aux-lib-dir)
(let ((dst (build-path python-aux-lib-dir "MoinMoin")))
  (make-directory dst)
  (replicate-directory-tree (build-path python-lib-dir "MoinMoin") dst)
  (copy-preserve python-aux-lib-dir-readme python-aux-lib-dir))
(delete-directory/files python-lib-dir) ; we use the zip and/or python-aux-lib-dir
(newline)

(echo "~%~%~%NOW FIRE UP XCode and build.~%~%")

;;; END OF SCRIPT FILE
