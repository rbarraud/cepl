(in-package :cepl.context)

;;----------------------------------------------------------------------

(defun+ set-context-defaults (cepl-context)
  ;; Set up the cache for samplers
  (setf (%cepl-context-array-of-bound-samplers cepl-context)
        (make-array (gl:get* :max-combined-texture-image-units)
                    :element-type '(or null sampler)
                    :initial-element nil))

  (let ((len (gl:get* :max-draw-buffers)))
    (setf (%cepl-context-color-masks cepl-context)
          (make-array len :element-type '(simple-array boolean (4))
                      :initial-contents
                      (loop :for i :below len :collect
                         (make-array 4 :element-type 'boolean
                                     :initial-element nil)))))

  (let ((stencil-params (%make-stencil-params)))
    (setf (%cepl-context-current-stencil-params-front cepl-context)
          stencil-params)
    (setf (%cepl-context-current-stencil-params-back cepl-context)
          stencil-params))

  ;; Enable depth testing and use 'less than' for testing
  (setf (depth-test-function cepl-context)
        #'<)
  ;; Writing to depth buffer enabled by default
  (setf (depth-mask cepl-context) t)
  ;; Set the default depth range
  (setf (depth-range-vec2 cepl-context)
        (v! 0 1))
  ;; Enable the depth clamp
  (setf (depth-clamp cepl-context)
        t)
  ;; Enable backface culling
  (setf (cull-face cepl-context)
        :back)
  ;; Set culling winding order
  (setf (front-face cepl-context)
        :ccw)
  ;; Default clear color
  (setf (clear-color cepl-context)
        (v! 0 0 0 0)))

;;----------------------------------------------------------------------

(defgeneric on-host-initialized (context)
  (:method ((context cepl-context))
    (unless (initialized-p context)
      (when (remove context *contexts*)
        (assert (cepl.host:supports-multiple-contexts-p) ()
                "CEPL: Sorry your current CEPL host does not currently support multiple contexts"))
      ;; make the surfaces
      (init-pending-surfaces context)
      ;;
      (when (surfaces context)
        (make-surface-current context (first (surfaces context))))
      ;;
      context)))
