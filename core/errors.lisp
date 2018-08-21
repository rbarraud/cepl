(in-package :cepl.errors)

(deferror gfun-invalid-arg-format () (gfun-name invalid-pair)
    "CEPL - defun-g: defun-g expects its parameter args to be typed in the~%format (var-name type), but instead ~s was found in the definition for ~s" invalid-pair gfun-name)

(deferror gpu-func-spec-not-found () (name types)
    "CEPL - gpu-func-spec: Could not find spec for the gpu-function named ~s
with the in-arg types ~s"
  name types)

(deferror dispatch-called-outside-of-map-g () (name)
    "Looks like you tried to call the pipeline ~s without using map-g.~%" name)

(deferror invalid-keywords-for-shader-gpipe-args () (pipeline-name keys)
    "Found some invalid keys in the pipeline called ~a:~%~s"
  pipeline-name keys)

(deferror invalid-context-for-assert-gpipe () (context)
    "CEPL: ~a is an invalid context for asserting whether gpipe args are valid"
  context)

(deferror invalid-context-for-assert-options () (context)
    "CEPL: ~a is an invalid context for asserting whether pipeline options are valid"
  context)

(deferror invalid-shader-gpipe-form () (pipeline-name valid-forms invalid-forms)
    "When using defpipeline-g to compose GPU functions, the valid stage specifiers are function literals~%(optionally with keyword stage names).~%~%In the defpipeline-g for ~a ~athese forms were not valid:~%~{~s~%~}~%"
  pipeline-name
  (if valid-forms
      (format nil "these forms were valid:~%~{~s~%~}~%However"
              valid-forms)
      "")
  invalid-forms)

(deferror not-enough-args-for-implicit-gpipe-stages () (pipeline-name clauses)
    "Tried to compile the pipeline ~a; however, there are not enough functions here for a valid pipeline:~%~s"
  pipeline-name clauses)

(deferror invalid-shader-gpipe-stage-keys () (pipeline-name keys)
    "In the defpipeline-g form for ~s the gpipe args are incorrect.~%~s"
  pipeline-name
  (let ((unknown-keys (remove-if (lambda (x) (member x varjo:*stage-names*))
                                 keys)))
    (if unknown-keys
        (format nil "The following stages are not supported, or are incorrectly named: ~a"
                unknown-keys)
        (format nil "The order of the following stages is incorrect:~%~s~%Valid order of stages is: ~a"
                keys varjo:*stage-names*))))

(deferror invalid-compose-gpipe-form () (pipeline-name clauses)
    "In the defpipeline-g for ~s there are some invalid pass clauses.~%

~{~a~%~}

A pass clause's first element is the destination; the last element is the call
to another CEPL pipeline. The elements between these are optional Lisp forms to
 run in the context of the destination.

Example valid forms:
~%(f0 (blit stream :tex tx))         -- where f0 is an fbo
~%(nil (blit stream :tex tx))        -- nil stands in for the default fbo
~%(f0 (clear) (blit stream :tex tx)) -- where the #'clear is running inside the implicit with-fbo"
  pipeline-name clauses)

(deferror invalid-defpipeline-options () (pipeline-name invalid-options valid-options)
    "CEPL - defpipeline-g: The defpipeline-g for ~a contained the following invalid options:~%~a~%The valid options to this form of defpipeline-g are:~s" pipeline-name invalid-options valid-options)

(deferror shader-pipeline-non-null-args () (pipeline-name)
    "CEPL - defpipeline-g: In defpipeline-g for ~a. Args are not needed in pipelines composed of g-functions"
  pipeline-name)


(deferror make-tex-no-content-no-type () ()
    "CEPL - make-texture: Trying to make texture, but have no element-type or
initial-contents to infer the type from")

(deferror make-tex-array-not-match-type ()
    (element-type pixel-format supposed-type array-type)
    "CEPL - make-texture: Trying to make texture, but the element-type given was
~s which implies an pixel-format of ~s.
That pixel-format would require an array element-type of ~s.
This conflicts with the array element-type of ~s"
  element-type pixel-format supposed-type array-type)

(deferror make-tex-array-not-match-type2 () (element-type initial-contents)
    "CEPL - make-texture: Trying to make texture with an element-type of ~s,
however, the initial-contents provided do not seem to be compatible:~%~s"
  element-type initial-contents)

(deferror image-format->lisp-type-failed () (type-name)
    "CEPL - make-texture: to find a conversion from the image-format ~s to a Lisp type"
  type-name)

(deferror lisp-type->image-format-failed () (type-name)
    "CEPL - make-texture: to find a suitable conversion from the Lisp type ~s to an
internal texture format"
  type-name)

(deferror pixel-format->image-format-failed () (type-name)
    "CEPL - make-texture: to find a suitable conversion from the pixel format ~s to an
internal texture format"
  type-name)

(deferror image-format->pixel-format-failed () (type-name)
    "CEPL - unable to find a suitable conversion from the internal
 texture format ~s to a pixel format"
  type-name)

(deferror buffer-backed-texture-invalid-args () ()
    "CEPL - make-texture: Buffer-backed textures cannot have mipmaps, multiple layers, or be cube rectangle or multisample")

(deferror buffer-backed-texture-invalid-samplers () ()
    "CEPL - make-texture: We do not currently support setting any texture sampling parameters on buffer-backed textures")

(deferror buffer-backed-texture-invalid-image-format () (type-name)
    "CEPL - make-texture: The internal format ~a is invalid for use with buffer-backed-textures"
  type-name)

(deferror buffer-backed-texture-establish-image-format () (type-name)
    "CEPL - make-texture: Could not establish the correct texture type for a buffer texture: ~a"
  type-name)

(deferror failed-to-test-compile-gpu-func (:error-type warning) (gfunc-name missing-func-names)
    "CEPL - defun-g: Failed to test compile the gpu function named '~s,
 as not all dependent functions having been compiled yet.
 Missing funcs: ~s
 To disable this warning for all future compilations:
 (setf cepl.pipelines:*warn-when-cant-test-compile* nil)" gfunc-name missing-func-names)


(deferror dont-define-space-to-self () (space)
    "with-model-space: please dont try redefining the relationship between ~s and itself."
  space)

(deferror index-on-buffer-stream-with-no-gpu-arrays () ()
    "Cepl: Invalid attempt to make buffer-stream with an index array even
though there were no gpu-arrays.")

(deferror struct-in-glsl-stage-args () (arg-names)
    "Found arguments to def-glsl-stage which have struct types.
Arg names: ~s
This is not currently supported by def-glsl-stage"
  arg-names)

(deferror make-gpu-array-from-c-array-mismatched-dimensions ()
    (c-arr-dimensions provided-dimensions)
    "CEPL: make-gpu-array mismatched dimensions

A call to #'make-gpu-array was made with a c-array as the initial-contents.
The dimensions of the c-array are ~s; however, the dimensions given in the
call to #'make-gpu-array were ~s"
  c-arr-dimensions provided-dimensions)

(deferror symbol-stage-designator () (designator possible-choices)
    "CEPL: defpipeline-g found a stage that was incorrectly specified.

The problematic defintition was: ~s

The problem: because of potential overloading, CEPL stages must be fully qualified.

~a"
  designator
  (if (= (length possible-choices) 1)
      (format nil "Instead of ~s please use: ~s"
              designator (first possible-choices))
      (format nil "Instead of ~s please use one of the following:~%~{~s~^~%~}"
              designator possible-choices)))

(deferror symbol-stage-designators () (designator-choice-pairs)
    "CEPL: defpipeline-g found a stage that was incorrectly specified.

The problematic stage designators were:
~{~s ~}

The problem: because of potential overloading, CEPL stages must be fully
qualified. ~{~%~%~a~}"
  (mapcar #'first designator-choice-pairs)
  (loop :for (designator choices) :in designator-choice-pairs :collect
     (if (= (length choices) 1)
         (format nil "Instead of ~s, please use: ~s"
                 designator (first choices))
         (format nil "Instead of ~s, please use one of the following:~%~{~s~^~%~}"
                 designator choices))))

(deferror stage-not-found () (designator)
    "CEPL - defpipeline-g: Could not find a gpu-function called ~s.
This most likely means it hasn't been compiled yet or that the name is incorrect"
  designator)

(deferror pixel-format-in-bb-texture () (pixel-format)
    "CEPL: make-texture was making a buffer-backed texture, however a
pixel-format was provided. This is invalid, as pixel conversion is not done when
uploading data to a buffer-backed texture.

Pixel-format: ~s"
  pixel-format)

(deferror glsl-version-conflict () (issue)
    "CEPL: When trying to compile the pipeline we found some stages which have
conflicting glsl version requirements:
~{~s~%~}" issue)

(deferror glsl-version-conflict-in-gpu-func () (name context)
    "CEPL: When trying to compile ~a we found multiple glsl versions.
Context: ~a" name context)

(deferror delete-multi-func-error () (name choices)
    "CEPL: When trying to delete the GPU function ~a we found multiple
overloads and didn't know which to delete for you. Please try again using one of
the following:
~{~s~%~}" name choices)

(deferror multi-func-error () (name choices)
    "CEPL: When trying find the gpu function ~a we found multiple overloads and
didn't know which to return for you. Please try again using one of
the following:
~{~s~%~}" name choices)

(defwarning pull-g-not-cached () (asset-name)
    "Either ~s is not a pipeline/gpu-function or the code for this asset
has not been cached yet"
  asset-name)

(deferror pull*-g-not-enabled () ()
    "CEPL has been set to not cache the results of pipeline compilation.
See the *cache-last-compile-result* var for more details")

(defwarning func-keyed-pipeline-not-found () (callee func)
    "CEPL: ~a was called with ~a.

When functions are passed to ~a we assume this is a either pipeline function
or a gpu-lambda. After checking that is wasnt a gpu-lambda we looked for the
details for a matching pipeline. However we didn't find anything.

Please note that you cannot lookup non-lambda gpu-functions in this way as,
due to overloading, many gpu-functions map to a single function object."
  callee func callee)

(deferror attachments-with-different-sizes (:print-circle nil) (args sizes)
    "CEPL: Whilst making an fbo we saw that some of the attachments will end up
having different dimensions: ~a

Whilst this is not an error according to GL it can trip people up because
according to the spec:

 > If the attachment sizes are not all identical, rendering will
 > be limited to the largest area that can fit in all of the
 > attachments (an intersection of rectangles having a lower left
 > of (0 0) and an upper right of (width height) for each attachment).

If you want to make an fbo with differing arguments, please call make-fbo
with `:matching-dimensions nil` in the arguments e.g.

 (MAKE-FBO ~{~%     ~a~})

"
  sizes
  (labels ((ffa (a)
             (typecase a
               ((or null keyword) (format nil "~s" a))
               ((or list symbol) (format nil "'~s" a))
               (otherwise (format nil "~s" a)))))
    (append (mapcar #'ffa args)
            '(":MATCHING-DIMENSIONS NIL"))))


(deferror invalid-cube-fbo-args () (args)
    "CEPL: Invalid args for cube-map bound fbo:

args: ~s

You have passed a cube-map texture without an attachment number; this
means you want the fbo to have 6 color attachments which are bound to the
faces of the cube texture.

Whilst using this feature, the only other legal argument is depth
attachment info.
" args)


(deferror functions-in-non-uniform-args () (name)
    "
CEPL: We currently only support functions as uniform arguments.

Pipeline: ~s"
  name)

(deferror mapping-over-partial-pipeline () (name args)
    "CEPL: This pipeline named ~s is a partial pipeline.

This is because the following uniform arguments take functions:
~{~%~s~}

As OpenGL does not itself support passing functions as values you must use
bake-uniforms to create set the uniforms above. This will generate
a 'complete' pipeline which you can then map-g over.
" name args)

(deferror fbo-target-not-valid-constant () (target)
    "CEPL: with-fbo-bound form found with invalid target

The target must be constant and must be one of the following:

- :framebuffer
- :read-framebuffer
- :draw-framebuffer

In this case the compile-time value of 'target' was: ~a
" target)

(deferror bake-invalid-pipeling-arg () (invalid-arg)
    "CEPL: The pipeline argument to #'bake was expected to be a pipeline name or
pipeline function object.

Instead we found: ~s"
  invalid-arg)

(deferror bake-invalid-uniform-name () (proposed invalid)
    "CEPL: An attempt to bake some uniforms in a pipeline has failed.

The arguments to be baked were:
~{~s ~s~^~%~}

However the following uniforms were not found in the pipeline:
~{~s~^ ~}"
  proposed invalid)

(deferror bake-uniform-invalid-values (:print-circle nil) (proposed invalid)
    "CEPL: An attempt to bake some uniforms in a pipeline has failed.

The arguments to be baked were:
~{~s ~s~^~%~}

However the following values are ~a, they are not representable in shaders.
~{~s~^ ~}

Might you have meant to specify a gpu function?"
  proposed
  (cond
    ((every #'symbolp invalid) "symbols")
    ((every #'listp invalid) "lists")
    (t "invalid"))
  invalid)

(deferror partial-lambda-pipeline (:print-circle nil) (partial-stages)
    "CEPL: pipeline-g was called with at least one stage taking functions as uniform
arguments.

If this were defpipeline-g we would make a partial pipeline however we don't
currently support partial lambda pipelines.

Sorry for the inconvenience. It is a feature we are interested in adding so if
this is causing you issues please reach out to us on Github.

The problem stages were:
~{~%~s~}"
  partial-stages)

(deferror glsl-geom-stage-no-out-layout (:print-circle nil) (glsl-body)
    "CEPL: def-glsl-stage was asked to make a geometry stage however it
could not find a valid 'out' layout declaration. These lines look something
like this:

layout(<primitive-name>, max_vertices=20) out;

Where <primitive-name> is one of points, line_strip or triangle_strip and
max_vertices is any integer.

Here is the block of glsl we search in:

~a" glsl-body)

(deferror invalid-inline-glsl-stage-arg-layout (:print-circle nil) (name arg)
    "CEPL: Invalid arg layout found in ~a. The correct layout for a argument to
a glsl-stage is (\"string-name-of-arg\" arg-type ,@keyword-qualifiers)

Problematic arg was: ~a"
  name arg)


(deferror adjust-gpu-array-mismatched-dimensions () (current-dim new-dim)
    "CEPL: adjust-gpu-array cannot currently change the number of dimensions in
a gpu-array.

current dimensions: ~a
proposed new dimensions: ~a

If working around this limitation proves to be too difficult please report it
on github so we can re-evaluate this limitation."
  current-dim new-dim)

(deferror adjust-gpu-array-shared-buffer () (array shared-count)
    "CEPL: adjust-gpu-array cannot currently adjust the size of gpu-array
which is sharing a gpu-buffer with other gpu-arrays.

Array: ~a is sharing a gpu buffer with ~a other gpu-arrays"
  array shared-count)

(deferror buffer-stream-has-invalid-primitive-for-stream ()
    (name pline-prim stream-prim)
    "CEPL: The buffer-stream passed to ~a contains ~s, however ~a
was expecting ~s.

You can either change the type of primitives the pipeline was expecting e.g:

 (defpipeline-g ~s (~s)
   ..)

Or you can create a stream with containing ~a e.g:

  (make-buffer-stream gpu-array :draw-mode ~s)

It is also worth noting that it is possible to pass triangles to a
pipeline declared to take (:patch 3), to pass lines to pipelines declared
to take (:patch 2) and points to pipelines taking (:patch 1)"
  name stream-prim name pline-prim
  name stream-prim
  pline-prim pline-prim)

(deferror invalid-options-for-texture ()
    (buffer-storage
     cubes dimensions layer-count mipmap multisample rectangle)
    "CEPL: We could not establish the correct texture type for the following
combination of options:

buffer-storage - ~a
cubes          - ~a
dimensions     - ~a
layer-count    - ~a
mipmap         - ~a
multisample    - ~a
rectangle      - ~a

If the GL spec says this is valid then we are sorry for the mistake. If you
have the time please report the issue here:
https://github.com/cbaggers/cepl/issues"
  buffer-storage cubes dimensions layer-count mipmap multisample rectangle)

(deferror gpu-func-symbol-name () (name alternatives env)
    "CEPL: We were asked to find the gpu function named ~a. Now we did find
~a however as gpu-functions can be overloaded we now require that you specify
the types along with the name. This is slightly more annoying when there is
only one match, however it eliminates the ambiguity that occurs as soon as
someone does overload the gpu-function.

Here are the possible names for this function:
~{~a~}
~@[
You may pick a implementation to use this time but, as this will not update
your code, you will get this error on the next compile unless it is fixed~]"
  name
  (if (> (length alternatives) 1)
      "matches"
      "a match")
  alternatives
  (not (null env)))

(deferror gl-context-initialized-from-incorrect-thread ()
    (ctx-thread init-thread)
    "CEPL: This CEPL context is tied to thread A (shown below) however something
tried to create the gl-context from thread B:
A: ~a
B: ~a"
  ctx-thread init-thread)

(deferror shared-context-created-from-incorrect-thread ()
    (ctx-thread init-thread)
    "CEPL: This CEPL context is tied to thread A (shown below) however something
tried to create a shared CEPL context using it from thread B:
A: ~a
B: ~a"
  ctx-thread init-thread)

(deferror tried-to-make-context-on-thread-that-already-has-one ()
    (context thread)
    "CEPL: An attempt was made to create a context on thread ~a however
that thread already has the CEPL context ~a.

In CEPL you may only have 1 CEPL context per thread. That context then holds
the handles to any GL contexts and any caching related to those gl contexts"
  thread context)

(deferror max-context-count-reached () (max)
    "CEPL: Currently CEPL has a silly restriction on the number of contexts
that can be active at once. The current maximum is max.

It's silly in that GL itself doesnt have this restriction and it was only
introduced in CEPL to make the implementation of multi-threading simpler.

This restriction does need to be removed however so if you are hitting
this then please report it at https://github.com/cbaggers/cepl. This lets us
know that this is causing real issues for people and we can prioritize it
accordingingly.")

(deferror nested-with-transform-feedback () ()
    "CEPL: Detected a nested with-transform-feedback form.

Currently this is not supported however in future it may be possible
to support on GLv4 and up.")

(deferror non-consecutive-feedback-groups () (groups)
    "CEPL: Currently when you specify transform-feedback groups their
numbers must be consecutive and there must be at least one value being written
to :feedback or (:feedback 0).

We hope to be able to relax this in future when we support more recent
GL features, however even then if you want maximum compatibility this
will remain a good rule to follow.

These were the groups in question: ~s" groups)

(deferror mixed-pipelines-in-with-tb () ()
    "CEPL: Different pipelines have been called within same tfs block")

(deferror incorrect-number-of-arrays-in-tfs () (tfs tfs-count count)
    "CEPL: The transform feedback stream currently bound has ~a arrays bound,
however the current pipeline is expecting to write into ~a ~a.

The stream in question was:~%~a"
  tfs-count
  count
  (if (= count 1) "array" "arrays")
  tfs)

(deferror invalid-args-in-make-tfs () (args)
    "CEPL: make-transform-feedback-stream was called with some arguments that
are not buffer-backed gpu-arrays:~{~%~s~}" args)

(defwarning tfs-setf-arrays-whilst-bound () ()
    "CEPL: There was an attempt to setf the arrays attached to the
transform-feedback-stream whilst it is bound inside with-transform-feedback.

It is not possible to make these changes whilst in the block so we will apply
them at the end of with-transform-feedback's scope")

(deferror one-stage-non-explicit () ()
    "CEPL: When defining a pipeline with only 1 stage you need to explicitly
mark what stage it is as CEPL is unable to infer this.

For example:

    (defpipeline-g some-pipeline ()
      :vertex (some-stage :vec4))")

(deferror invalid-stage-for-single-stage-pipeline () (kind)
    "CEPL: We found a pipeline where the only stage was of type ~a.
Single stage pipelines are valid in CEPL however only if the stage is
a vertex, fragment or compute stage" kind)

(deferror pipeline-recompile-in-tfb-scope () (name)
    "CEPL: We were about to recompile the GL program behind ~a however we
noticed that this is happening inside the scope of with-transform-feedback
which GL does not allow. Sorry about that." name)

(deferror compile-g-missing-requested-feature () (form)
    "CEPL: Sorry currently compile-g can only be used to make gpu lambdas
by passing nil as the name and the source for the lambda like this:

    (lambda-g ((vert :vec4) &uniform (factor :float))
      (* vert factor))

We recieved:
~a
" form)

(deferror query-is-already-active () (query)
    "CEPL: An attempt was made to start querying using the query object listed
below, however that query object is currently in use.

query: ~s" query)

(deferror query-is-active-bug () (query)
    "CEPL BUG: This error should never be hit as it should have
been covered by another assert inside #'begin-gpu-query.

we are sorry for the mistake. If you have the time please report the issue
here: https://github.com/cbaggers/cepl/issues

query: ~s" query)

(deferror another-query-is-active () (query current)
    "CEPL: An attempt was made to begin querying with query object 'A' listed
below however query object 'B' of the same kind was already active on this
context. GL only allows 1 query of this kind to be active at a given time.

Query A: ~s
Query B: ~s" query current)

(deferror query-not-active () (query)
    "CEPL: A call was made to #'end-gpu-query with the query object listed
below. The issue is that the query object is not currently active so it is
not valid to try and make it inactive.

Query: ~s" query)

(deferror compute-pipeline-must-be-single-stage () (name stages)
    "CEPL: A attempt was made to compile ~a which contains the following
stage kinds: ~a

However if you include a compute stage it is the only stage allowed in the
pipeline. Please either remove the compute stage or remove the other stages."
  (if name name "a pipeline")
  stages)

(deferror could-not-layout-type () (type)
    "CEPL BUG: We were unable to work out the layout for the type ~a

We are sorry for the mistake. If you have the time please report the issue
here: https://github.com/cbaggers/cepl/issues

   (if you are able to include the definition of the type in the
    issue report that we be excedingly helpful)" type)

(deferror invalid-data-layout-specifier () (specifier valid-specifiers)
    "CEPL: ~a is not a valid layout data specifier.
Please use one of the following: ~{~a~^, ~}"
  specifier valid-specifiers)

(deferror invalid-layout-for-inargs () (name type-name layout)
    "CEPL: ~a is not a valid type for ~a's input arguments as it has
the layout ~a.

~a can only be used for uniforms marked as :ubo or :ssbo."
  type-name
  (or name "this lambda pipeline")
  layout
  type-name)

(deferror invalid-layout-for-uniform () (name type-name layout func-p)
    "CEPL: ~a is not a valid type for ~a's uniform argument as it has
the layout ~a. std-140 & std-430 layouts are only valid for ubo & ssbo
uniforms."
  type-name
  (or name
      (if func-p
          "this gpu-lambda"
          "this lambda pipeline"))
  layout)

(deferror c-array-total-size-type-error () (size required-type)
    "CEPL: c-array's total size must be of type c-array-index,
also known as ~a. Total size found was ~a"
  (upgraded-array-element-type required-type)
  size)

(deferror state-restore-limitation-transform-feedback () ()
    "CEPL: State restoring currently cannot be used from within the dynamic
scope of a transform feedback")

(deferror state-restore-limitation-blending () ()
    "CEPL: State restoring currently cannot be used from within the dynamic
scope of with-blending (may have been introduced by with-fbo-bound)")

(deferror state-restore-limitation-queries () ()
    "CEPL: State restoring currently cannot be used from within the dynamic
scope of with-blending (may have been introduced by with-fbo-bound)")


(deferror fbo-binding-missing () (kind current-surface)
    "CEPL: FBO ~a bindings missing from context.
~a"
  (string-downcase (string kind))
  (if current-surface
      ""
      "This is probably due to there being no surface current on this context"))

(deferror texture-dimensions-lequal-zero () (dimensions)
    "CEPL: Found an request to make a texture where at least one of the
dimensions were less than or equal to zero.

Dimensions: ~a"
  dimensions)

(deferror unknown-symbols-in-pipeline-context () (name full issue for)
    "
CEPL: Found something we didnt recognise in the context of ~a

Problematic symbol/s: ~{~s~^, ~}
Full context: ~s

The pipeline context must contain:

The symbol :static at most once and..

..0 or more of the following glsl versions:~{~%- :~a~}

and at most 1 primitive from:
- :dynamic
- :points
- :lines
- :iso-lines
- :line-loop
- :line-strip
- :lines-adjacency
- :line-strip-adjacency
- :triangles
- :triangle-fan
- :triangle-strip
- :triangles-adjacency
- :triangle-strip-adjacency
- (:patch <patch length>)
"
  (ecase for
    (:function
     (if name
         (format nil "the gpu-function named ~a." name)
         (format nil "a gpu-lambda.")))
    (:pipeline
     (if name
         (format nil "the pipeline named ~a." name)
         (format nil "a lambda pipeline.")))
    (:glsl-stage
     (if name
         (format nil "the glsl stage named ~a." name)
         (format nil "a glsl stage.")))) ;; this one should never happend
  issue
  full
  varjo:*supported-versions*)

(deferror stage-in-context-only-valid-for-glsl-stages () (name)
    "
~a had a stage declaration in it's `compile-context` list
this is only valid for gpu-functions & glsl stages.
"
  (if name
      (format nil "The pipeline named ~a" name)
      "A lambda pipeline"))

(deferror unknown-stage-kind () (stage)
    "
Unknown stage kind '~a'

Valid stage kinds are:~{~%- ~s~}"
  stage
  varjo:*stage-names*)

(deferror stage-not-valid-for-function-restriction () (name stage func-stage)
    "
When compiling ~a we found that the function being used as the ~a stage has
a restriction that means it is only valid to be used as a ~a stage.
"
  (or name "a lambda pipeline")
  stage
  func-stage)

(deferror gl-version-too-low-for-empty-fbos () (version)
    "
We found a valid attempt to create an empty fbo, however these are only
supported in GL versions 4.3 and above.

Current version: ~a
" version)

(deferror invalid-attachments-for-empty-fbo () (args)
    "
When defining an empty fbo there can be 0 or 1 attachment
declarations. When present it's name must be NIL.

For example:
- `(make-fbo '(nil :dimensions (1024 1024)))`
- `(make-fbo '(nil))`
- `(make-fbo)`

You may also optionally specify the following parameters as you would
in `make-texture`:

- :dimensions
- :layer-count
- :samples
- :fixed-sample-locations

The empty fbo can be 1 or 2 dimensional

In this case we were passed the following declarations:~{~%- ~s~}
" args)

(deferror invalid-empty-fbo-declaration () (decl)
    "
When defining an empty fbo there can only be 1 attachment declaration,
it's name must be NIL, and dimensions must be specified.

For example: `(make-fbo '(nil :dimensions (1024 1024))`

Dimensions can be 1 or 2 dimensional

You may also optionally specify the following parameters as you would
in `make-texture`:

- :layer-count
- :samples
- :fixed-sample-locations

In this case we were passed the following declaration:~%- ~s
" decl)

(deferror quote-symbol-found-in-fbo-dimensions () (form)
    "
During creation of an fbo we found the quote symbol in the 'dimensions'
portion of the attachment form.

As the attachment form was already quoted this is unnecessary.

Form: ~s
" form)

(deferror attachment-viewport-empty-fbo () (fbo attachment)
    "
`T` cannot be used as a attachment-name. It is only allowed in
`with-fbo-viewport` & `with-fbo-bound`'s 'attachment-for-size' parameter
and only if the fbo being bound is empty.

Likewise, when trying to use the above (and only the above) on an empty fbo,
the attachment name *must* be 'T'.

FBO Found: ~a
Attachment: ~a
" fbo attachment)

(deferror invalid-fbo-args () (args)
    "
")

(deferror invalid-sampler-wrap-value () (sampler value)
    "
CEPL: Invalid value provided for 'wrap' of sampler:

Sampler: ~a
Value: ~s

The value must be one of the following
- :repeat
- :mirrored-repeat
- :clamp-to-edge
- :clamp-to-border
- :mirror-clamp-to-edge

or a vector of 3 of the above keywords.
" sampler value)

(deferror make-gpu-buffer-from-id-clashing-keys () (args)
    "
CEPL: When calling make-gpu-buffer-from-id you can pass in either
initial-contents or layout, but not both.

Args: ~s
" args)

(deferror invalid-gpu-buffer-layout () (layout)
    "
CEPL: When calling make-gpu-buffer-from-id and passing in layouts, each
layout must be either:

- A positive integer representing a size in bytes
- A list contain both :dimensions and :element-type &key arguments.

e.g.
- 512
- '(:dimensions (10 20) :element-type :uint8)

layout: ~s
" layout)

(deferror invalid-gpu-arrays-layout () (layout)
    "
CEPL: When calling make-gpu-arrays-from-buffer-id each layout must be
a list containing both :dimensions and :element-type &key arguments.

e.g.
- '(:dimensions (10 20) :element-type :uint8)

layout: ~s
" layout)

(deferror gpu-array-from-id-missing-args () (element-type dimensions)
    "
CEPL: When calling make-gpu-array-from-buffer-id element-type and
dimensions as mandatory.

element-type: ~s
dimensions: ~s
" element-type dimensions)

(deferror gpu-array-from-buffer-missing-args () (element-type dimensions)
    "
CEPL: When calling make-gpu-array-from-buffer element-type and
dimensions as mandatory.

element-type: ~s
dimensions: ~s
" element-type dimensions)

(deferror quote-in-buffer-layout () (layout)
    "
CEPL: The symbol 'quote' was found in the gpu-buffer layout, making the
layout list invalid. This was probably a typo.

layout: ~s
" layout)

(deferror make-arrays-layout-mismatch () (current-sizes requested-sizes)
    "
CEPL: When settting make-gpu-array-from-buffer's :keep-data argument
to T you are requesting that the arrays are made using the existing contents
of the buffer. However, in this case the byte size of the requested gpu arrays
would not fit in the current available sections of the gpu-buffer.

Current Section Sizes: ~a
Requested gpu-array sizes: ~a
" current-sizes requested-sizes)

(deferror make-arrays-layout-count-mismatch () (current-count layouts)
    "
CEPL: When settting make-gpu-array-from-buffer's :keep-data argument
to T you are requesting that the arrays are made using the existing contents
of the buffer. However, in this case the number of layouts provided (~s) does
not match the number of sections in the gpu-buffer (~s).

Layouts: ~s
" (length layouts) current-count layouts)

(deferror cannot-keep-data-when-uploading () (data)
    "
CEPL: When calling make-gpu-buffer-from-id with keep-data it is not valid
to pass initial-contents. The reason is that we would be required to upload
the data in those c-arrays, which means we would not be keeping our promise
to 'keep-data'.

keep-data can be used when passing layouts instead of initial-contents as
there we are just replacing CEPL's understanding of the layout of data in
the buffer, without changing what is actually there.

initial-contents provided:
~s
" data)

(deferror invalid-stream-layout () (layout)
    "
CEPL: When calling make-buffer-stream-from-id-and-layouts each
layout must be a list containing both :dimensions and :element-type
&key arguments.

e.g.
- '(:dimensions (500) :element-type :vec3)

layout: ~s
" layout)

(deferror index-on-buffer-stream-with-no-gpu-layouts () ()
    "
CEPL: Invalid attempt to make buffer-stream with an index layout even
though there were no data layouts.")

(deferror cannot-extract-stream-length-from-layouts () (layouts)
    "
CEPL: We were unable to compute a suitable length for the buffer-stream
as at least one of the data-layouts had an unknown length and there was
no index-layout for us to take into account

layouts: ~s" layouts)

(deferror index-layout-with-unknown-length () (layout)
    "
CEPL: When make-buffer-stream-from-id-and-layouts is called and an index
layout is provided, it may not have '?' as the dimensions.

layout: ~s" layout)

(deferror inconsistent-struct-layout () (name target slots)
    "
CEPL: the attempt to define the gpu-structs named ~a failed as, whilst it was
defined to have a ~a layout, the following slots had different layouts:
~{~%- ~a~}
" name target slots)

(deferror not-a-gpu-lambda () (thing)
    "CEPL: ~a does not appear to be a gpu-lambda"
  thing)

(deferror bad-c-array-element () (incorrect-type
                                  correct-type
                                  elem
                                  initial-contents
                                  extra-info-string)
    "
CEPL: The first element in the initial-contents to the array being created
is a ~a, this is not valid for an array of ~a

First Value: ~s
Initial-Contents: ~s~@[~%~%~a~]"
  incorrect-type
  correct-type
  elem
  initial-contents
  extra-info-string)

(deferror no-named-stages () (stages)
    "
CEPL: Small issue in a pipeline definition. Only a pipeline with 2 stages can
be implicitly named, others must have explicit named stages.

In this case we recieved the following for the stages:

~{~s~%~}
Each of these stages will need to be named with one each of the following:
~{~%- ~a~}"
  stages
  varjo.api:*stage-names*)

(deferror bad-type-for-buffer-stream-data () (type)
    "
CEPL: ~s is not a type we can use for the data passed to the shader in a
buffer-stream or vao as glsl does not directly support that type.~@[~%~%~a~]"
  type
  (when (find type '(:short :ushort :signed-short :unsigned-short))
    "Perhaps this was meant to be used as the index?"))

;; Please remember the following 2 things
;;
;; - add your condition's name to the package export
;; - keep this comment at the bottom of the file.
;;
;; Thanks :)
