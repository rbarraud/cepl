(in-package :cepl.gpu-buffers)

;;;--------------------------------------------------------------
;;; BUFFERS ;;;
;;;---------;;;

;; [TODO] Should buffers have pull-g and push-g? of course! do it :)

(defmethod print-object ((object gpu-buffer) stream)
  (if (initialized-p object)
      (format stream "#<GPU-BUFFER ~a ~@[~a~]>"
              (gpu-buffer-id object)
              (map 'list #'gpu-array-bb-byte-size (gpu-buffer-arrays object)))
      (format stream "#<GPU-BUFFER :UNINITIALIZED>")))

(defmethod free ((object gpu-buffer))
  (free-buffer object))

(defun+ blank-buffer-object (buffer)
  (setf (gpu-buffer-id buffer) 0)
  (setf (gpu-buffer-arrays buffer)
        (make-array 0 :element-type 'gpu-array-bb
                    :initial-element +null-buffer-backed-gpu-array+
                    :adjustable t :fill-pointer 0))
  buffer)

(defun+ free-gpu-buffer (buffer)
  (with-cepl-context (ctx)
    (with-foreign-object (id :uint)
      (setf (mem-ref id :uint) (gpu-buffer-id buffer))
      (cepl.context::forget-gpu-buffer ctx buffer)
      (blank-buffer-object buffer)
      (%gl:delete-buffers 1 id))))

(defun+ free-buffer (buffer)
  (free-gpu-buffer buffer))

(defun+ free-gpu-buffers (buffers)
  (with-cepl-context (ctx)
    (with-foreign-object (id :uint (length buffers))
      (loop :for buffer :in buffers :for i :from 0 :do
         (setf (mem-aref id :uint i) (gpu-buffer-id buffer))
         (cepl.context::forget-gpu-buffer ctx buffer)
         (blank-buffer-object buffer))
      (%gl:delete-buffers 1 id))))

(defun+ free-buffers (buffers)
  (free-gpu-buffers buffers))

(defun+ gen-buffer ()
  (first (gl:gen-buffers 1)))

(defun+ init-gpu-buffer-now (new-buffer
                             gl-object
                             initial-contents
                             buffer-target
                             usage)
  (declare (symbol buffer-target usage))
  (with-cepl-context (ctx)
    (setf (gpu-buffer-id new-buffer) gl-object)
    (cepl.context::register-gpu-buffer ctx new-buffer)
    (if initial-contents
        (if (list-of-c-arrays-p initial-contents)
            (multi-buffer-data new-buffer initial-contents buffer-target usage)
            (buffer-data new-buffer initial-contents
                         :target buffer-target :usage usage))
        new-buffer)))

(defun process-layout (layout)
  (cond
    ((and (integerp layout) (>= layout 0))
     layout)
    ((and (listp layout)
          (find :dimensions layout)
          (find :element-type layout))
     (destructuring-bind (&key dimensions element-type) layout
       (let* ((dimensions (listify dimensions))
              (elem-count (reduce #'* dimensions))
              (element-type (if (cepl.pixel-formats:pixel-format-p element-type)
                                (pixel-format->lisp-type element-type)
                                element-type)))
         (* elem-count (gl-type-size element-type)))))
    ((and (listp layout)
          (eq (first layout) 'quote))
     (error 'quote-in-buffer-layout :layout layout))
    (t (error 'invalid-gpu-buffer-layout :layout layout))))

(defun init-gpu-buffer-now-with-layouts (new-buffer
                                         gl-object
                                         layouts
                                         usage
                                         keep-data)
  (declare (symbol usage))
  (let* ((layouts (listify layouts))
         (byte-sizes (mapcar #'process-layout layouts)))
    (with-cepl-context (ctx)
      (setf (gpu-buffer-id new-buffer) gl-object)
      (cepl.context::register-gpu-buffer ctx new-buffer)
      (if keep-data
          (buffer-set-arrays-from-sizes new-buffer byte-sizes usage)
          (buffer-reserve-blocks-from-sizes new-buffer
                                            byte-sizes
                                            :array-buffer
                                            usage))
      new-buffer)))

(defun+ list-of-c-arrays-p (x)
  (and (listp x) (every #'c-array-p x)))

(defun+ make-gpu-buffer-from-id (gl-object &rest args
                                           &key initial-contents
                                           layouts
                                           (buffer-target :array-buffer)
                                           (usage :static-draw)
                                           (keep-data nil))
  (declare (symbol buffer-target usage))
  (assert (not (and layouts initial-contents)) ()
          'make-gpu-buffer-from-id-clashing-keys
          :args args)
  (if layouts
      (init-gpu-buffer-now-with-layouts (make-uninitialized-gpu-buffer)
                                        gl-object
                                        layouts
                                        usage
                                        keep-data)
      (progn
        (assert (not keep-data) () 'cannot-keep-data-when-uploading
                :data initial-contents)
        (init-gpu-buffer-now (make-uninitialized-gpu-buffer)
                             gl-object
                             initial-contents
                             buffer-target
                             usage))))

(defun+ make-gpu-buffer (&key initial-contents
                          (buffer-target :array-buffer)
                          (usage :static-draw))
  (declare (symbol buffer-target usage))
  (assert (or (null initial-contents)
              (typep initial-contents 'c-array)
              (list-of-c-arrays-p initial-contents)))
  (cepl.context::if-gl-context
   (init-gpu-buffer-now
    %pre% (gen-buffer) initial-contents buffer-target usage)
   (make-uninitialized-gpu-buffer)))

(defun+ buffer-data-raw (data-pointer byte-size buffer
                        &optional (target :array-buffer) (usage :static-draw)
                        (byte-offset 0))
  (setf (gpu-buffer-bound (cepl-context) target) buffer)
  (%gl:buffer-data target byte-size
                   (cffi:inc-pointer data-pointer byte-offset)
                   usage)
  buffer)

(defun+ buffer-data (buffer
                     c-array
                     &key
                     (target :array-buffer)
                     (usage :static-draw)
                     (offset 0)
                     byte-size)
  (let ((byte-size (or byte-size (cepl.c-arrays::c-array-byte-size c-array))))
    (buffer-data-raw (pointer c-array)
                     byte-size
                     buffer target usage (* offset (element-byte-size c-array)))
    (buffer-set-arrays-from-sizes buffer (list byte-size) usage)))

(defun+ multi-buffer-data (buffer c-arrays target usage)
  (let* ((c-array-byte-sizes (loop :for c-array :in c-arrays :collect
                                (cepl.c-arrays::c-array-byte-size c-array))))
    (map nil #'free (gpu-buffer-arrays buffer))
    (setf (gpu-buffer-bound (cepl-context) target) buffer)
    (buffer-reserve-blocks-from-sizes buffer c-array-byte-sizes target usage)
    (loop :for c :in c-arrays :for g :across (gpu-buffer-arrays buffer) :do
       (gpu-array-sub-data g c :types-must-match nil))
    buffer))

(defun+ gpu-array-sub-data (gpu-array c-array &key (types-must-match t))
  (when types-must-match
    (assert (equal (gpu-array-bb-element-type gpu-array)
                   (c-array-element-type c-array))))
  (let ((byte-size (cepl.c-arrays::c-array-byte-size c-array))
        (byte-offset (gpu-array-bb-offset-in-bytes-into-buffer
                      gpu-array)))
    (unless (>= (gpu-array-bb-byte-size gpu-array) byte-size)
      (error "The data you are trying to sub into the gpu-array does not fit
c-array: ~s (byte-size: ~s)
gpu-array: ~s (byte-size: ~s)"
             c-array byte-size
             gpu-array (gpu-array-bb-byte-size gpu-array)))
    (setf (gpu-buffer-bound (cepl-context) :array-buffer)
          (gpu-array-bb-buffer gpu-array))
    (%gl:buffer-sub-data :array-buffer byte-offset byte-size (pointer c-array))
    gpu-array))

(defun+ buffer-reserve-block-raw (buffer byte-size target usage)
  (setf (gpu-buffer-bound (cepl-context) target) buffer)
  (%gl:buffer-data target byte-size (cffi:null-pointer) usage)
  buffer)

(defun+ buffer-reserve-block (buffer type dimensions target usage
                                     &key (row-alignment 1))
  (unless dimensions (error "dimensions are not optional when reserving a buffer block"))
  (setf (gpu-buffer-bound (cepl-context) target) buffer)
  (let* ((dimensions (listify dimensions))
         (byte-size (cepl.c-arrays::gl-calc-byte-size type dimensions
                                                      row-alignment)))
    (buffer-reserve-block-raw buffer byte-size target usage)
    (buffer-set-arrays-from-sizes buffer (list byte-size) usage))
  buffer)

(defun+ buffer-reserve-blocks-from-sizes (buffer byte-sizes target usage)
  (check-type byte-sizes list)
  (let ((total-size (reduce #'+ byte-sizes)))
    (setf (gpu-buffer-bound (cepl-context) target) buffer)
    (buffer-reserve-block-raw buffer total-size target usage)
    (buffer-set-arrays-from-sizes buffer byte-sizes usage)
    buffer))

(defun+ buffer-set-arrays-from-sizes (buffer byte-sizes usage)
  (check-type byte-sizes list)
  (map nil #'free (gpu-buffer-arrays buffer))
  (let ((offset 0))
    (setf (gpu-buffer-arrays buffer)
          (make-array
           (length byte-sizes)
           :element-type 'gpu-array-bb
           :initial-contents
           (loop :for byte-size :in byte-sizes
              :collect (%make-gpu-array-bb
                        :dimensions (list byte-size)
                        :buffer buffer
                        :access-style usage
                        :element-type :uint8
                        :byte-size byte-size
                        :offset-in-bytes-into-buffer offset
                        :row-alignment 1)
              :do (incf offset byte-size)))))
  buffer)


(defun+ reallocate-buffer (buffer)
  (assert (= (length (gpu-buffer-arrays buffer)) 1))
  (let ((curr (aref (gpu-buffer-arrays buffer) 0)))
    (buffer-reserve-block-raw buffer
                              (gpu-array-bb-byte-size curr)
                              :array-buffer
                              (gpu-array-bb-access-style curr))))

;;---------------------------------------------------------------
