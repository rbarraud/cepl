(in-package :cepl.pipelines)

;; extract details from args and delegate to %def-gpu-function
;; for the main logic
(defmacro defun-g (name args &body body)
  (defun-g-common name args body nil))

(defmacro defun-g-equiv (name args &body body)
  (defun-g-common name args body t))

(defun+ defun-g-common (name args body equiv)
  "Define a function that runs on the gpu."
  ;; The code here splits and validates the arguments but the meat
  ;; of gpu function definition happens in the %def-gpu-function call
  ;; at the tail
  ;; -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -
  ;; seperate any doc-string or declarations from the body
  (multiple-value-bind (code decls doc-string)
      (varjo.internals::extract-declares-and-doc-string
       body `(define-vari-function ,name ,args ,@body))
    (declare (ignore code decls))
    ;; split the argument list into the categoried we care aboutn
    (assoc-bind ((in-args nil) (uniforms :&uniform) (raw-context :&context)
                 (shared :&shared))
        (varjo.utils:lambda-list-split '(:&uniform :&context :&shared) args)
      ;; check the arguments are sanely formatted
      (mapcar #'(lambda (x) (assert-arg-format name x)) in-args)
      (mapcar #'(lambda (x) (assert-arg-format name x)) uniforms)
      ;; now the meat
      (%def-gpu-function name in-args uniforms body shared
                         doc-string equiv raw-context))))

(defun+ assert-arg-format (gfunc-name x)
  (unless (listp x)
    (error 'gfun-invalid-arg-format :gfun-name gfunc-name :invalid-pair x))
  x)

;;--------------------------------------------------

(defun+ %def-gpu-function (name in-args uniforms body shared
                          doc-string equiv raw-context)
  "This is the meat of defun-g. it is broken down as follows:

   [0] makes a gpu-func-spec that will be populated a stored later.

   [1] Adds a external function definition to varjo also make sure it will be
       called on load

   [2] %test-&-process-spec compiles the code to check for errors and log
       dependencies. (this is called at runtime)

   [3] %make-gpu-func-spec is called at expand time to write a lisp function
       with the same signature as the gpu-function. This gives code hinting and
       also a decent error message if you try calling it from the cpu.
       We don't do this when using defun-g-equiv as we want to shadow the lisp
       function.

   [4] the purpose of %recompile-gpu-function-and-pipelines is to recompile and
       functions or pipelines that depend on this gpu function. It does this
       by calling %recompile-gpu-function-and-pipelines on all the gpu function
       that depend on this func and then the recompile-function for all
       pipelines that depend on this gpu function. To this end it walks depth
       first too all affected pipelines.

   [5] At runtime this looks for any gpu function that listed this function as
       one of its missing dependencies and calls %test-&-process-spec on them.
       Note that this will (possibly) update the spec but will not trigger a
       recompile in the pipelines."
  (let* ((compile-context (parse-compile-context name raw-context :function))
         (spec (%make-gpu-func-spec name in-args uniforms compile-context
                                    body shared nil nil uniforms doc-string
                                    nil nil (get-gpu-func-spec-tag))) ;;[0]
         (valid-glsl-versions (compile-context-versions compile-context))
         (spec-key (spec->func-key spec))
         (old-spec (gpu-func-spec spec-key nil))
         (changedp (spec-changed-p spec old-spec))
         (spec (if changedp
                   spec
                   old-spec)))
    ;; this gets the functions used in the body of this function
    ;; it is *not* recursive
    (%update-gpu-function-data spec nil nil)
    (varjo:add-external-function name in-args uniforms body
                                 valid-glsl-versions);;[1]
    `(progn
       (varjo:add-external-function ',name ',in-args ',uniforms ',body
                                    ',valid-glsl-versions);;[1]
       ,(unless equiv (make-stand-in-lisp-func spec));;[3]
       (%test-&-process-spec ,spec);;[2]
       ,(when changedp
          `(%recompile-gpu-function-and-pipelines ,spec-key));;[4]
       (update-specs-with-missing-dependencies);;[5]
       ',name)))



(defun+ lowest-suitable-glsl-version (compile-context)
  (let* ((versions (compile-context-versions compile-context)))
    (case= (length versions)
      (0 (cepl.context::get-best-glsl-version versions))
      (otherwise (first versions)))))

(defvar *warn-when-cant-test-compile* t)

(defun+ %test-&-process-spec (spec &key (cache-spec t))
  "Use varjo to compile the code.
   [0] If the compilation throws a could-not-find-function error, then record
   that missing function's name as a missing dependency.

   [1] If it succeeds then look at the list of used external-functions, and
   check which of the names of the macros match the names of a gpu function.
   The ones that match are the dependencies.

   [2] We also record the uniforms in the compiled result. The uniforms in the
   definition are the public interface, but the compiler may have removed or
   modified the uniforms. To this end we store the final uniforms and the forms
   that transform between the public uniform arguments and the internal ones.

   [3] We call 'add-layout-to-struct-uniforms' here to ensure that the ubo/ssbo
   arguments have the correct layout information. This is not important for
   the test compilation, but instead for the uniform information that is
   gathered from this test compile (actual-uniforms)."
  (with-gpu-func-spec spec
    (handler-case
        (varjo:with-constant-inject-hook #'try-injecting-a-constant
          (varjo:with-stemcell-infer-hook #'try-guessing-a-varjo-type-for-symbol
            (varjo:with-unknown-first-class-functions-allowed
              (let* ((varjo.internals::*allow-call-function-signature* t)
                     (versions (list (lowest-suitable-glsl-version context)))
                     (uniforms (add-layout-to-struct-uniforms name
                                                              :function
                                                              uniforms));;[3]
                     (compiled
                      (first
                       (varjo.internals::test-translate-function-split-details
                        name in-args uniforms versions body varjo:*stage-names* t))))
                (setf actual-uniforms ;;[2]
                      (mapcar #'varjo.internals:to-arg-form
                              (remove-if #'varjo:ephemeral-p
                                         (varjo.api:uniform-variables compiled))))

                (when cache-spec
                  (%update-gpu-function-data
                   spec
                   (remove-if-not #'gpu-func-spec
                                  (varjo:used-external-functions compiled)) ;;[1]
                   compiled))))))
      ;; vv- called if failed
      (varjo-conditions:could-not-find-function (e) ;;[0]
        (setf missing-dependencies (list (slot-value e 'varjo.internals:name)))
        (when *warn-when-cant-test-compile*
          (format t "~% cepl: the function ~s was not found when compiling ~s"
                  (first missing-dependencies) name))
        (when cache-spec
          (%update-gpu-function-data spec nil nil))))
    spec))




(defmethod %recompile-gpu-function-and-pipelines (key)
  (%recompile-gpu-function-and-pipelines (func-key key)))

(defmethod %recompile-gpu-function-and-pipelines ((key func-key))
  "Recompile all pipelines that depend on the named gpu function or any other
   gpu function that depends on the named gpu function. It does this by doing
   the following:

   [0] Recursively call this function on all gpu functions that use the
       gpu function named in the argument

   [1] Trigger a recompile on all pipelines that depend on this gpu function"
  ;; recompile gpu-funcs that depends on name
  (mapcar #'%recompile-gpu-function-and-pipelines
          (funcs-that-use-this-func key));;[0]
  ;; update diff-tag
  (with-gpu-func-spec (gpu-func-spec key)
    (setf diff-tag (get-gpu-func-spec-tag)))
  ;; and recompile pipelines that depend on name
  (recompile-pipelines-that-use-this-as-a-stage key))

(defun+ %update-gpu-function-data (spec depends-on compiled)
  "[0] Add or update the spec

   [1] (re)subscribe to all the dependencies

   [2] cache the compile result so we can retrieve it with #'pull1-g
       or the code with #'pull-g"
  (%unsubscibe-from-all spec);;[1]
  (map nil (lambda (x) (%subscribe-to-gpu-func spec x)) depends-on) ;;[1]
  (when *cache-last-compile-result*
    (setf (slot-value spec 'cached-compile-results) compiled));;[2]
  (setf (gpu-func-spec spec) spec));;[0]

(defun+ %update-glsl-stage-data (spec)
  "[0] Add or update the spec"
  (setf (gpu-func-spec spec) spec));;[0]

(defvar *print-gpu-function-subscriptions* nil)

(defmethod %subscribe-to-gpu-func (func subscribe-to)
  "As the name would suggest this makes one function dependent on another
   It is used by #'%test-&-process-spec via #'%update-gpu-function-data "
  (let ((func (func-key func))
        (subscribe-to (func-key subscribe-to)))
    (assert (not (func-key= func subscribe-to)))
    (symbol-macrolet ((func-specs (funcs-that-use-this-func subscribe-to)))
      (when (and (gpu-func-spec subscribe-to)
                 (not (member func func-specs :test #'func-key=)))
        (when *print-gpu-function-subscriptions*
          (format t "; func ~s subscribed to ~s~%"
                  (name func)
                  (name subscribe-to)))
        (push func func-specs)))))

(defun+ make-stand-in-lisp-func (spec)
  "Makes a regular lisp function with the same names and arguments
  (where possible) as the gpu function who's spec is provided.

  If called the function will throw an error saying that the function
  can't currently be used from the cpu.

  This means we get function arg hints, doc-string and also we have the
  opportunity to provide a cpu implementation one day we want to."
  (with-gpu-func-spec spec
    `(setf (symbol-function ',name)
           (lambda (&rest args)
             ,@(when doc-string (list doc-string))
             (apply #'funcall-g ',name args)))))

;;--------------------------------------------------

(defun+ aggregate-uniforms (name
                            target-kind
                            func-specs
                            &optional actual-uniforms-p)
  "The reason we need to aggregate uniforms is as follows:
   - pipelines are made of composed gpu functions
   - each gpu function may introduce uniforms
   - to this end we need to make sure the different functions' uniforms are
     compatible and then return a final list of aggregated uniforms.

   The way we do this is:
   [0] Remove all duplicates, this handles all cases where the same uniform is
       in different gpu-functions
   [1] Now if there is any more than one instance of each uniform name then
       there is a clash

   Sidenote:
   [X] We call 'add-layout-to-struct-uniforms' here to ensure that the ubo/ssbo
       arguments have the correct layout information. This is not important for
       the test compilation, but instead for the uniform information that is
       gathered from this test compile (actual-uniforms)."
  (assert (every (lambda (x) (typep x 'gpu-func-spec))
                 func-specs))
  (labels ((get-uniforms (spec)
             (add-layout-to-struct-uniforms
              name
              target-kind
              (with-gpu-func-spec spec
                (copy-list
                 (if actual-uniforms-p
                     actual-uniforms
                     uniforms)))))
           (normalize-type-names (uniform)
             (dbind (name type &rest rest) uniform
               (let ((type (varjo:type->type-spec
                            (varjo:type-spec->type
                             type))))
                 `(,name ,type ,@rest)))))
    ;;
    (let* ((uniforms (mapcan #'get-uniforms func-specs))
           (uniforms (mapcar #'normalize-type-names uniforms))
           (uniforms (remove-duplicates uniforms :test #'equal)) ;; [0]
           (all-clashes
            (loop :for uniform :in uniforms :collect
               (let* ((name (first uniform))
                      (clashes (remove-if-not (lambda (x) (eq name (first x)))
                                              uniforms)))
                 (when (> (length clashes) 1) ;; [1]
                   (list (first uniform) clashes)))))
           (all-clashes (remove-duplicates (remove nil all-clashes)
                                           :key #'first)))
      (when all-clashes
        (error "CEPL: Uniforms found in pipeline with incompatible definitions:
~{~%~a~}"
               (mapcar (lambda (x)
                         (format nil "~s:~{~%~s~}~%" (first x) (second x)))
                       all-clashes)))
      uniforms)))

;;--------------------------------------------------

(defun+ get-func-as-stage-code (func-spec)
  (with-gpu-func-spec func-spec
    (list in-args uniforms shared context body)))

;;--------------------------------------------------

(defun+ %varjo-compile-as-pipeline (name primitive parsed-gpipe-args)
  "Compile the gpu functions for a pipeline
   The argument to this function is a list of pairs.
   Each pair contains:
   - the shader stage (e.g. vertex fragment etc)
   - the name of the gpu function to use for this stage"
  (varjo:with-constant-inject-hook #'try-injecting-a-constant
    (varjo:with-stemcell-infer-hook #'try-guessing-a-varjo-type-for-symbol
      (varjo:rolling-translate
       (loop
          :for (stage-type . func-spec) :in parsed-gpipe-args
          :collect (parsed-gpipe-args->v-translate-args name
                                                        primitive
                                                        stage-type
                                                        func-spec))))))

(defun+ add-layout-to-struct-uniforms (name target-kind uniforms)
  (assert (member target-kind '(:pipeline :function)))
  (flet ((add-layout-to-struct-uniform (name arg)
           (let* ((type-spec
                   (second arg))
                  (struct-info
                   (cepl.types::g-struct-info type-spec
                                              :error-if-not-found nil)))
             (if struct-info
                 (let ((layout (cepl.types::s-layout struct-info)))
                   (when layout
                     (assert (or (find :ssbo arg) (find :ubo arg))
                             ()
                             'invalid-layout-for-uniform
                             :name name
                             :func-p (eq target-kind :function)
                             :type-name type-spec
                             :layout (class-name (class-of layout))))
                   (etypecase layout
                     (null arg)
                     (std-140 (if (find :std-140 arg)
                                  arg
                                  (append arg (list :std-140))))
                     (std-430 (if (find :std-430 arg)
                                  arg
                                  (append arg (list :std-430))))))
                 arg))))
    (mapcar (lambda (arg) (add-layout-to-struct-uniform name arg))
            uniforms)))

;; {TODO} make the replacements related code more robust
(defun+ parsed-gpipe-args->v-translate-args (name
                                             pipeline-primitive
                                             stage-kind
                                             func-spec
                                             &optional replacements)
  "parsed-gpipe-args->v-translate-args processed the (stage . gfunc-name) pairs
   that %compile-link-and-upload want to call v-rolling-translate on.
   To do this we need to look up the gpu function spec and turn them into valid
   arguments for the rolling-translate function.
   It also:
   [0] if it's a glsl-stage then it is already compiled. Pass the
       compile-result and let varjo handle it
   [1] is what handles the transformation of func (including gpu-lambdas)
   [2] 'replacements' specifies uniforms to replace in the stage. "
  (assert (every #'listp replacements))
  (if (typep func-spec 'glsl-stage-spec)
      (with-glsl-stage-spec func-spec
        compiled);;[0]
      (dbind (in-args uniforms shared compile-context code)
          (get-func-as-stage-code func-spec) ;;[1]
        (loop :for arg :in in-args :do
           (let* ((type-spec (second arg))
                  (struct-info
                   (cepl.types::g-struct-info type-spec
                                              :error-if-not-found nil)))
             (when struct-info
               (let ((layout (cepl.types::s-layout struct-info)))
                 (assert (null layout) ()
                         'invalid-layout-for-inargs
                         :name name
                         :type-name type-spec
                         :layout (class-name (class-of layout)))))))
        (let* ((uniforms (add-layout-to-struct-uniforms name
                                                        :pipeline
                                                        uniforms))
               (final-uniforms (remove-if (lambda (u)
                                            (member (first u) replacements
                                                    :key #'first
                                                    :test #'string=))
                                          uniforms))
               (replacements ;; [2]
                (loop :for (k v) :in replacements
                   :for r = (let* ((u (find k uniforms :key #'first
                                            :test #'string=)))
                              (when (and u (typep (varjo:type-spec->type
                                                   (second u))
                                                  'varjo:v-function-type))
                                (list (first u) `(the ,(second u)
                                                      (function ,v)))))
                   :when r :collect r))
               (body (if replacements
                         `((let ,replacements
                             ,@code))
                         code))
               (versions (compile-context-versions compile-context))
               (func-stage (compile-context-stage compile-context)))
          (when func-stage
            (assert (eq stage-kind func-stage) ()
                    'stage-not-valid-for-function-restriction
                    :name name
                    :stage stage-kind
                    :func-stage func-stage))
          ;; {TODO} we need to use the function's primitive
          (varjo:create-stage stage-kind
                              versions
                              :input-variables in-args
                              :uniform-variables final-uniforms
                              :shared-variables shared
                              :code body
                              :stemcells-allowed t
                              :primitive (when (eq stage-kind :vertex)
                                           pipeline-primitive))))))

;;--------------------------------------------------

(defun+ get-possible-designators-for-name (name)
  (mapcar (lambda (x)
            (with-gpu-func-spec x
              (cons name (mapcar #'second in-args))))
          (gpu-func-specs name)))

(defun+ get-stage-key (stage-designator &optional options-on-error)
  (cond
    ((and (listp stage-designator) (eq (first stage-designator) 'function))
     (get-stage-key (second stage-designator)))
    ((functionp stage-designator)
     (lambda-g->func-spec stage-designator))
    ((symbolp stage-designator)
     (let* ((name stage-designator)
            (funcs (gpu-func-specs name)))
       (if (= (length funcs) 0)
         (error 'stage-not-found :designator name)
         (error 'gpu-func-symbol-name
                :name stage-designator
                :alternatives (mapcar (lambda (x)
                                        (with-gpu-func-spec x
                                          (cons stage-designator
                                                (mapcar #'second in-args))))
                                      funcs)
                :env options-on-error))))
    ((listp stage-designator)
     (let ((key (new-func-key (first stage-designator)
                              (rest stage-designator))))
       (if (gpu-func-spec key)
           key
           (error 'stage-not-found :designator stage-designator))))
    (t (error "CEPL: Bug in get-stage-key - ~s" stage-designator))))

(defun+ parse-gpipe-args (args)
  "Gets the stage pairs and context for the given gpipe form.
   If there are only two gpu functions named and no explicit stages then
   it is assumed that the first is the vertex stage and the second the fragment
   stage.
   Otherwise you are expected to name the stages. You can name one and then let
   this function fill in the rest, but I think that's a bit hairy and will
   probably be removed.

   stage pairs are of the form (stage-name . gpu-function-name)"
  (let ((cut-pos (or (position :post args) (length args))))
    (destructuring-bind (&key post) (subseq args cut-pos)
      (let* ((args (subseq args 0 cut-pos))
             (len (length args)))
        (list
         (pairs-key-to-stage
          (cond
            ((and (= len 2) (not (some #'keywordp args)))
             (parse-gpipe-args-implicit args))
            ((= len 1) (error 'one-stage-non-explicit))
            (t
             (assert (= (count-if #'keywordp args)
                        (floor len 2))
                     () 'no-named-stages :stages args)
             (parse-gpipe-args-explicit args))))
         post)))))

(defun+ parse-gpipe-args-implicit (args)
  (destructuring-bind (v-key f-key) (validate-stage-names args)
    (list (cons :vertex v-key)
          (cons :fragment f-key))))

(defun complete-single-stage-pipeline (stage)
  (case (first stage)
    (:fragment
     (list (cons :vertex (get-stage-key '(cepl.pipelines::stateless-quad-vertex-stage)))
           (cons :geometry (get-stage-key '(cepl.pipelines::stateless-quad-geometry-stage)))
           stage))
    (:vertex
     (list stage))
    (:compute
     (list stage))
    (otherwise (error 'invalid-stage-for-single-stage-pipeline))))

(defun massage-compute-stage-name (name)
  ;; we allow a little massaging here as compute stages have no in-args so
  ;; there can be no overloading. In these cases it feels bit mean to be
  ;; as harsh on signature
  (cond
    ((symbolp name) (list name))
    ((and (listp name)
          (eq (first name) 'function)
          (symbolp (second name))
          (second name))
     `(function (,(second name))))
    (t name)))

(defun+ parse-gpipe-args-explicit (args)
  (dbind (&key vertex tessellation-control tessellation-evaluation
               geometry fragment compute) args
    (let ((compute (when compute
                     (massage-compute-stage-name compute))))
      (dbind (v-key tc-key te-key g-key f-key c-key)
          (validate-stage-names (list vertex tessellation-control
                                      tessellation-evaluation
                                      geometry fragment compute))
        (let ((result
               (remove nil
                       (list (when vertex
                               (cons :vertex v-key))
                             (when tessellation-control
                               (cons :tessellation-control tc-key))
                             (when tessellation-evaluation
                               (cons :tessellation-evaluation te-key))
                             (when geometry
                               (cons :geometry g-key))
                             (when fragment
                               (cons :fragment f-key))
                             (when compute
                               (cons :compute c-key))))))
          ;;
          ;; single fragment pipeline
          (if (= 1 (length result))
              (complete-single-stage-pipeline (first result))
              result))))))

(defun+ validate-stage-names (names)
  (let* (invalid
         (valid
          (loop :for name :in names :collect
             (when name
               (let ((sn (if (typep name 'func-key)
                             name
                             (get-stage-key name))))
                 (if sn
                     sn
                     (progn
                       (push (list name
                                   (get-possible-designators-for-name name))
                             invalid)
                       nil)))))))
    (case= (length invalid)
      (0 valid)
      (1 (let ((fail (first invalid)))
           (error 'symbol-stage-designator
                  :designator (first fail)
                  :possible-choices (second fail))))
      (otherwise (error 'symbol-stage-designators
                        :designator-choice-pairs (reverse invalid))))))

;;--------------------------------------------------

(defun+ try-injecting-a-constant (constant-name)
  (assert (constantp constant-name))
  (let ((val (symbol-value constant-name)))
    (typecase val
      (single-float val)
      (double-float val)
      ((signed-byte 32) val)
      ((unsigned-byte 32) val))))

(defun+ try-guessing-a-varjo-type-for-symbol (s)
  "This function is provided to varjo to allow inference of the
   types of implicit uniforms."
  ;; only works on specials because of symbol-value
  (when (boundp s)
    (guess-a-varjo-type (symbol-value s))))

(defgeneric infer-implicit-uniform-type (thing)
  (:method (thing)
    (declare (ignore thing))
    nil))

(defun+ guess-a-varjo-type (x)
  (typecase x
    (number (guess-a-varjo-number-type x))
    (array (guess-a-varjo-array-type x))
    (boolean (guess-a-varjo-bool-type x))
    (sampler (%sampler-type x))
    (t (or (infer-implicit-uniform-type x)
           (error "Cant guess a suitable type for ~s" x)))))

(defun+ guess-a-varjo-bool-type (x)
  (if (eql x t)
      :bool
      (error "Cant guess a suitable type for ~s" x)))

(defun+ guess-a-varjo-array-type (x)
  (typecase x
    ((simple-array single-float (2)) :vec2)
    ((simple-array single-float (3)) :vec3)
    ((simple-array single-float (4)) :vec4)
    ((simple-array single-float (9)) :mat3)
    ((simple-array single-float (16)) :mat4)))

(defun+ guess-a-varjo-number-type (x)
  (typecase x
    ((or single-float double-float) (guess-a-varjo-float-type x))
    (integer (guess-a-varjo-integer-type x))
    (t (error "Cant guess a suitable type for ~s" x))))

(defun+ guess-a-varjo-float-type (x)
  (if (typep x 'single-float)
      :float
      :double))

(defun+ guess-a-varjo-integer-type (x)
  (typecase x
    ((signed-byte 32) :int)
    ((unsigned-byte 32) :uint)
    (t (error "Cant guess a suitable type for ~s" x))))

;;--------------------------------------------------

(defmethod delete-gpu-function ((gfunc-description null)
                                &optional (error-if-missing t))
  (when error-if-missing
    (error 'gpu-func-spec-not-found :name gfunc-description :types nil)))

(defmethod delete-gpu-function ((gfunc-description symbol)
                                &optional (error-if-missing t))
  (let ((choices (gpu-functions gfunc-description)))
    (if (= (length choices) 1)
        (delete-gpu-function (first choices) error-if-missing)
        (restart-case (error 'delete-multi-func-error
                             :name gfunc-description
                             :choices choices)
          (use-value ()
            (interactive-delete-gpu-function gfunc-description))))))

(defmethod delete-gpu-function ((gfunc-description func-key)
                                &optional (error-if-missing t))
  (delete-gpu-function
   (cons (name gfunc-description) (in-args gfunc-description))
   error-if-missing))

(defmethod delete-gpu-function ((gfunc-description list)
                                &optional (error-if-missing t))
  (dbind (name . in-arg-types) gfunc-description
    (let* ((func-key (new-func-key name in-arg-types))
           (spec (gpu-func-spec func-key nil)))
      (if spec
          (progn
            (delete-func-spec func-key)
            (varjo:delete-external-function name in-arg-types))
          (when error-if-missing
            (error 'gpu-func-spec-not-found
                   :name (name func-key)
                   :types (in-args func-key))))
      gfunc-description)))



(defun+ interactive-delete-gpu-function (name)
  (let ((picked
         (read-gpu-function-choice
          "Please choose which of the following functions you wish to delete"
          name)))
    (when picked
      (format t "~%Deleting ~s" picked)
      (delete-gpu-function picked))))
