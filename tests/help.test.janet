(import ../src/init :as cmd)

(def greet
  (cmd/fn
    {:doc "This is a struct docstring"
     :epilogue "this is an epilogue"}
    [[--greeting -g] (optional :string "Hello") "What greeting to use"
     name :string "The name to be greeted"
     name2 :string "The second name to be greeted"]
    (printf "%s, %s!" greeting name)))

(def main-group
  (cmd/group 
   {:doc "This is a struct docstring"}
   greeting greet))

(defn declare-version []
  (print "test v0.0.1"))

(defn main [& args]
  (let [normalized-args (cmd/args)]
    (cond
      (has-value? normalized-args "--version") (do (declare-version)             (break))
      (has-value? normalized-args "-v")        (do (declare-version)             (break))
      (deep= normalized-args ["--help"])    (do (cmd/run main-group ["help"]) (break))
      (deep= normalized-args ["-h"])        (do (cmd/run main-group ["help"]) (break)))
    (cmd/run main-group (cmd/args))))