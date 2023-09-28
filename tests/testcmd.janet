(import /src :prefix "cmd/" :refresh true)

(comment 

  # Today, `testcmd help` prints this:
  
  ```
  A test main function

    greet - Greet someone by name.
    help  - explain a subcommand
    joke  - Tell a joke.
  ```

  # And `testcmd greet --help` prints this:

  ```  
  A test main function
  
    testcmd greet
   [NAME]
  
  === flags ===
  
    [--help]       : Print this help text and exit
  ```  

  # And `testcmd joke --help` prints this:
  
  ```
  Tell a joke.
  
    testcmd joke
  
  
  === flags ===
  
    [--help]        : Print this help text and exit
    [-f], [--funny] : Tell a funny joke.    
  ```
  
  # Preferably, `testcmd help` will print this: 

  ``` 
  A test main function

  USAGE
    testcmd <command> [flags]
  
  CORE COMMANDS 
    greet:      Greet the name given
    help:       Help about any command
  
  ADDITIONAL COMMANDS
    joke:       Tell a funny joke

  FLAGS
    --help      Show help for a command
    --version   Show testcmd version
  
  EXAMPLES
    $ testcmd name Caleb
    $ testcmd joke
    $ testcmd --help
  
  LEARN MORE
    See the README on GitHub: https://www.github.com/CFiggers/testcmd

  FEEDBACK
    Open an issue on GitHub: https://www.github.com/CFiggers/testcmd/issues
  ```
  
  # To get there, some things are needed:
  # 
  # - [ ] Ability to toggle printing a version number in the help printout
  # - [ ] Ability to smartly recognize when a command tree has subcommands vs just top-level commands
  # - [ ] Rework auto-generated "help" and "--help" command and flag, especially for `cmd/group`
  # - [ ] Ability to designate a command "CORE" vs "ADDITIONAL" (and other categories too perhaps)
  #     - Maybe if no categories given, Help defaults to "COMMANDS." 
  #     - But if there are categories assigned, separate into sections and prefix with category label
  # - [ ] Ability to smartly suggest "EXAMPLES" based on existing commands/flags (but allow override)
  # - [ ] Ability to add optional sections (LEARN MORE, and FEEDBACK)
  #     - Maybe allow grabbing GitHub repo details from .git remote? 
  
  )

(cmd/main
 (cmd/group
  "A test main function"
  greet (cmd/fn "Greet someone by name."
          [name (optional ["NAME" :string] "World") "Greet the name given."]
          (print "Hello, " name "!"))
  joke (cmd/fn "Tell a joke."
         [[--funny -f] (flag) "Tell a funny joke."]
         (if funny
           (print "'Oh no, I dropped my toothpaste!' said the man, crestfallen.")
           (print "What's brown and sticky? A stick!")))))