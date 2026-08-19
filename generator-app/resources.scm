(define-module (generator-app resources)
  #:use-module ((f) #:prefix f:)
  #:use-module (srfi srfi-1)
  #:use-module (ice-9 format)
  #:use-module (ice-9 string-fun)
  #:use-module (ice-9 textual-ports)
  #:use-module (oop goops)
  #:use-module (generator-app tools)
  #:use-module (generator-app genera-classi)
  #:use-module (generator-app generation-protocols)
  #:use-module (generator-app generation-state)
  #:re-export (register-image-set!)
  #:export (<image-set>
            image-set:name
            image-set:source-directory
            image-set:files
            materialize-image-sets!
            generate-image-resource-jucer-code
            update-jucer-image-resources!
            generated-resource-filename
            generate-image-resource-cpp-code))

(new-class <image-set>
           ()
           ((name "")
            (source-directory "")
            (files '()))
           #:code
           (register-image-set! this))

(define-method (register-image-set! (resource <image-set>))
  (let ((name (image-set:name resource))
        (source-directory (image-set:source-directory resource))
        (files (image-set:files resource)))
    (unless (and (string? name) (not (string-null? name)))
      (error "Image set requires a non-empty name"))
    (unless (and (string? source-directory)
                 (not (string-null? source-directory)))
      (error "Image set requires a non-empty source-directory" name))
    (unless (and (list? files) (every string? files))
      (error "Image set files must be a list of strings" name files))
    (for-each
     (lambda (file)
       (let ((path (string-append source-directory "/" name "/" file)))
         (unless (file-exists? path)
           (error "Image set file does not exist" name path))))
     files)
    (when (find
           (lambda (entry)
             (equal? (assoc-ref entry 'name) name))
           (generation-image-sets))
      (error "Duplicate image set name" name))
    (prepend-generation-image-set!
     `((name . ,name)
       (source-directory . ,source-directory)
       (files . ,files)))))

(define (generated-resource-filename set-name file)
  (string-append set-name "__" file))

(define (materialize-image-sets! dst-folder)
  (for-each
   (lambda (image-set)
     (let* ((name (assoc-ref image-set 'name))
            (source-directory (assoc-ref image-set 'source-directory))
            (files (assoc-ref image-set 'files))
            (source-set-directory
             (string-append source-directory "/" name))
            (destination-set-directory
             (string-append dst-folder "/Resources/" name)))
       (when (file-exists? destination-set-directory)
         (f:delete destination-set-directory #t))
       (mkdir destination-set-directory)
       (for-each
        (lambda (file)
          (let* ((generated-file
                  (generated-resource-filename name file))
                 (source
                  (string-append source-set-directory "/" file))
                 (destination
                  (string-append destination-set-directory
                                 "/"
                                 generated-file)))
            (copy-file source destination)))
        files)))
   (generation-image-sets))
  #t)

(define (generate-image-resource-jucer-code)
  (let ((counter 0))
    (define (next-id)
      (set! counter (+ counter 1))
      (format #f "GIR~4,'0d" counter))
    (string-concatenate
     (map
      (lambda (image-set)
        (let ((name (assoc-ref image-set 'name))
              (files (assoc-ref image-set 'files)))
          (string-concatenate
           (map
            (lambda (file)
              (let ((generated-file
                     (generated-resource-filename name file)))
                (format #f
                        "      <FILE id=\"~a\" name=\"~a\" compile=\"0\" resource=\"1\" file=\"Resources/~a/~a\"/>~%"
                        (next-id)
                        generated-file
                        name
                        generated-file)))
            files))))
      (reverse (generation-image-sets))))))

(define (update-jucer-image-resources! jucer-file)
  (let* ((start-marker "<!-- GENERATED IMAGE RESOURCES START -->")
         (end-marker "<!-- GENERATED IMAGE RESOURCES END -->")
         (generated-code (generate-image-resource-jucer-code))
         (generated-block
          (string-append "    " start-marker "\n" generated-code "    " end-marker))
         (content (call-with-input-file jucer-file get-string-all))
         (start-pos (string-contains content start-marker))
         (end-pos (string-contains content end-marker)))
    (if (and start-pos end-pos)
        (let* ((after-end (+ end-pos (string-length end-marker)))
               (new-content
                (string-append
                 (substring content 0 start-pos)
                 generated-block
                 (substring content after-end))))
          (call-with-output-file jucer-file
            (lambda (port) (display new-content port))))
        (let* ((resources-marker "name=\"Resources\"")
               (resources-pos (string-contains content resources-marker)))
          (unless resources-pos
            (error "Resources group not found in .jucer" jucer-file))
          (let ((group-end
                 (string-contains content "</GROUP>" resources-pos)))
            (unless group-end
              (error "Resources group has no closing </GROUP>" jucer-file))
            (let ((new-content
                   (string-append
                    (substring content 0 group-end)
                    generated-block
                    "\n"
                    (substring content group-end))))
              (call-with-output-file jucer-file
                (lambda (port) (display new-content port)))))))
    #t))

(define (binary-data-symbol-name set-name file)
  (let* ((resource-name (generated-resource-filename set-name file))
         (symbol-name
          (list->string
           (map
            (lambda (c)
              (if (or (char-alphabetic? c) (char-numeric? c)) c #\_))
            (string->list resource-name)))))
    (if (char-numeric? (string-ref symbol-name 0))
        (string-append "_" symbol-name)
        symbol-name)))

(define (generate-image-resource-cpp-code)
  (string-concatenate
   (map
    (lambda (image-set)
      (let* ((name (assoc-ref image-set 'name))
             (files (assoc-ref image-set 'files))
             (var-name
              (string-append "imageSet_" (logical-id->cpp-base name))))
        (string-append
         (format #f "    std::vector<juce::Image> ~a;~%" var-name)
         (string-concatenate
          (map
           (lambda (file)
             (let ((symbol (binary-data-symbol-name name file)))
               (format #f
                       "    ~a.push_back(juce::ImageCache::getFromMemory(BinaryData::~a, BinaryData::~aSize));~%"
                       var-name symbol symbol)))
           files))
         (format #f
                 "    kineticLNF.registerImageSet(\"~a\", ~a);~%~%"
                 name
                 var-name))))
    (reverse (generation-image-sets)))))
