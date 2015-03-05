async = require 'async'

{ EOL } = require 'os'

{ basename, dirname, join } = require 'path'

ACliCommand = require 'a-cli-command'

class Rename extends ACliCommand

  command:

    name: "rename"

    options:

      replace:

        type: "string"

        description: [
          "the replacement string"
        ]

      search:

        type: "string"

        description: [
          "the search parameter"
        ]

      contents:

        type: "boolean"

        description: [
          "specifies if file contents",
          "should also be searched",
          "and replace instances when",
          "matches are found"
        ]

      transform:

        type: "array"

        triggers: ["blacklist", "contents"]

        default: ["classify", "camelize", "humanize", "capitalize"]

        description: [
          "search and replace transformed string"
        ]

      blacklist:

        type: "array"

        default: [".gitignore", ".npmignore", "node_modules"]

        description: [
          "an array of string to blacklist",
          "when calling find for file content",
          "replacement"
        ]

  "execute?": (command, next) ->

    @shell

    { blacklist, contents, replace, transform, search } = command.args

    if not replace then return next "invalid replace #{replace}", null

    search = [search]

    replace = [replace]

    blacklisted = (file) ->

      if blacklist

        for string in blacklist

          if file.match string then return true

    if transform

      t =

        capitalize: (str) ->

          return str.charAt(0).toUpperCase() + str.slice(1)

        camelize: (str) ->

          return str.replace /(?:^|[-_])(\w)/g, (_, c) ->

            if c then return c.toUpperCase() else return ''

        classify: (str) ->

          t.capitalize t.camelize str

        humanize: (str) ->

          return ( str.split(/-|_/g).map (s) ->

            return t.capitalize s

          ).join " "

      terms = search: search, replace: replace

      for tr in transform

        for name, term of terms

          _t = t[tr] term[0]

          if name is "search" then _t = new RegExp "#{_t}", "g"

          term.push _t

      search[0] = new RegExp "#{search[0]}", "g"

    if contents

      files = find(process.cwd()).filter (file) ->

        if blacklisted file then return false

        return file.match search[0]

    else

      files = find(process.cwd()).filter (file) ->

        if blacklisted file then return false

        return basename(file).match search[0]

    _mv = {}

    cbs = []

    files.reverse().map (file) =>

      if basename(file).match(search[0])

        filename = basename(file).replace search[0], replace[0]

        _mv[file] = join dirname(file), filename

      if test "-f", file

        cbs.push (done) =>

          prev = cat file

          cur = prev

          for i in [0...search.length]

            cur = cur.replace(search[i],replace[i])

          _diff = () =>

            require 'colors'

            rw = false

            conflict =  ""

            diff = require 'diff'

            parts = diff.diffChars prev, cur

            parts.forEach (part) ->

              color = if part.added

                "green"

              else if part.removed

                "red"

              else color = "grey"

              if color isnt "grey" then rw = true

              conflict += part.value[color]

            if not rw then return done null, file

            @cli.prompt [{

              name: "confirm"

              type: "confirm",

              message: [

                "#{conflict}",

                "overwrite?"

              ].join EOL

              default: true

            }], (res) ->

              if res.confirm then cur.to file

              done null, file

          _diff()

    async.series cbs, (err, res) ->

      if err then return next err, null

      Object.keys(_mv).map (src) ->

        mv src, _mv[src]

      next null, "renamed"

module.exports = Rename
