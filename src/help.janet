(import ./util)
(import ./bridge)

# janet has no built-in way to detect the terminal width.
# might be nice to allow the user to set a dynamic variable,
# though...
(def- desired-width 100)

(defn- right-pad [str len]
  (string str (string/repeat " " (max 0 (- len (length str))))))

(defn- word-wrap-line [line len]
  (def lines @[])
  (var current-line @"")
  (def pad (or (first (peg/match '(<- :s+) line)) ""))
  (each word (string/split " " line)
    (when (and (not (empty? current-line))
             (>= (+ (length current-line) 1 (length word)) len))
      (array/push lines current-line)
      (set current-line @""))
    (when (not (empty? current-line))
      (buffer/push-string current-line " "))
    (buffer/push-string current-line word))
  (array/push lines current-line)
  (map |(string pad $) lines))

(defn- word-wrap [str len]
  (mapcat |(word-wrap-line $ len) (string/split "\n" (or str ""))))

(defn- zip-lines [lefts rights f]
  (def end (max (length lefts) (length rights)))
  (def last-i (- end 1))
  (for i 0 end
    (f (= i 0) (= i last-i) (get lefts i "") (get rights i ""))))

(defn- executable-name []
  (def executable-path (first (dyn *args*)))
  (last (string/split "/" executable-path)))

(defn wrap-handling [str value-handling]
  (case value-handling
    :required str
    :none (string "["str"]")
    :optional (string "["str"]")
    :variadic (string "["str"]...")
    :variadic+ (string str"...")
    :greedy (string "["str"...]")
    :soft-escape (string "["str"]")
    (errorf "BUG: unknown value handling %q" value-handling)))

(defn- format-arg-string [handler &opt str]
  (def {:value value-handling :type type} handler)
  (case value-handling
    :none nil
    :soft-escape nil
    (let [[first second] type]
      (if (string? first)
        first
        (let [sym (first str)
              # [tag [arg-name type]]
              [_ [arg _]] (second sym)]
          arg)))))

(defn- format-named-param [str handler]
  (def arg (format-arg-string handler str))
  (wrap-handling
    (if arg (string str " " arg) str)
    :required))

(defn- format-positional-param [handler]
  (wrap-handling
    (format-arg-string handler)
    (handler :value)))

(defn- print-wrapped [str len &opt prefix]
  (each line (word-wrap str len)
    (when prefix (prin prefix))
    (print line)))

(defn- lines [str]
  (string/split "\n" str))

(defn blank? [str]
  (all |(= (chr " ") $) str))

(defn parse-docstring [str]
  (if (nil? str)
    [nil nil]
    (let [[summary & detail] (lines str)]
      (def detail (drop-while blank? detail))
      [summary (if (not (empty? detail))
        (string/join detail "\n"))])))

(defn docstring-summary [{:doc str}]
  (case (util/type+ str)
    :string (or (first (parse-docstring str)) "")
    :struct (or (first (parse-docstring (str :doc))) "")
    :table  (or (first (parse-docstring (str :doc))) "")))

(defn print-columns [sep entries]
  (def left-column-width 
    (util/max-by |(util/max-by length (0 $)) entries))
  
  (each [lefts docstring] entries
    (def rights 
      (word-wrap docstring (max (/ desired-width 2) 
                                (- desired-width left-column-width))))

    (zip-lines lefts rights
               (fn [first? last? left right]
                 (def sep 
                   (if (empty? right) "" (if first? sep (string/repeat " " (length sep)))))
                 
                 (def pad-to 
                   (if (empty? right) 0 (+ left-column-width (if first? 0 2))))
                 
                 (print "  " (right-pad left pad-to) sep right)))))

(defn group [spec]
  (def outbuf @"")
  (setdyn :out outbuf)

  # TODO: word wrap
  (def {:doc docstring :commands commands} spec)
  (case (util/type+ docstring)
    :tuple-parens (print-wrapped docstring desired-width)
    :string       (print-wrapped docstring desired-width)
    :struct       (when (docstring :doc) 
                    (print-wrapped (docstring :doc) desired-width))
    :table        (when (docstring :doc) 
                    (print-wrapped (docstring :doc) desired-width))
    (print))

  (print "\nCommands:\n")
  (def commands (sorted-by 0 (pairs commands)))

  # TODO: bit of code duplication here
  (print-columns "      "
                 (seq [[name command] :in commands]
                   [[name] (docstring-summary command)]))

  (case (util/type+ docstring)
    :struct       (when (docstring :epilogue)
                    (print-wrapped (docstring :epilogue) desired-width))
    :table        (when (docstring :epilogue)
                    (print-wrapped (docstring :epilogue) desired-width)))
  (print)
  
  (file/write stdout outbuf)
  (setdyn :out stdout))

(defn- default-description [param]
  (case ((param :handler) :value)
    :soft-escape "Treat all subsequent arguments as positional"
    ""))

(defn simple [spec]
  (def outbuf @"")
  (setdyn :out outbuf)

  (def {:named named-params
        :names param-names
        :pos positional-params
        :doc docstring} spec)

  (prin "Usage: " (executable-name))
  
  (each subcommand (dyn bridge/*subcommand-path* [])
    (prin " " subcommand))
  
  (each param positional-params
    (prin " ")
    (prin (format-positional-param (param :handler))))
  
  (print "\n")

  (def [summary details]
    (case (util/type+ docstring)
      :string        (parse-docstring docstring)
      :tuple-parens  (parse-docstring docstring)
      :struct        (parse-docstring (docstring :doc))
      :table         (parse-docstring (docstring :doc))
      [nil nil]))
  
  (when summary 
    (print-wrapped summary desired-width "  ")
    (print))

  (when details
    (print-wrapped details desired-width)
    (print))

  (def named-arg-entries
    (seq [[_ param] :in (sorted-by 0 (pairs named-params))]
      (def {:names names} param)
      (def names (sorted-by |(string/triml $ "-") names))
      (def formatted-names (map |(format-named-param $ (param :handler)) names))
      # 2 is the length of the initial "  " and the separator ", "
      (def total-length (util/sum-by |(+ (length $) 2) formatted-names))
      (def lines (if (<= total-length (/ desired-width 3))
                   [(string/join formatted-names ", ")]
                   formatted-names))
      [lines (or (param :doc) (default-description param))]))

  (unless (empty? named-arg-entries)
    (print "Options:")

    (print-columns "   " named-arg-entries))

  (case (util/type+ docstring)
    :struct (when (docstring :epilogue) 
              (do (file/flush stdout)
                  (print-wrapped (docstring :epilogue) desired-width)))
    :table  (when (docstring :epilogue) 
              (do (file/flush stdout)
                  (print-wrapped (docstring :epilogue) desired-width))))

  (file/write stdout outbuf)
  (setdyn :out stdout))
