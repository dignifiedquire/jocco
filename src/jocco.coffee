# **Jocco** is a quick-and-dirty, hundred-line-long, literate-programming-style
# documentation generator. It produces HTML
# that displays your comments alongside your code. Comments are passed through
# [Markdown](http://daringfireball.net/projects/markdown/syntax), and code is
# passed through [Pygments](http://pygments.org/) syntax highlighting, if it
# is present on the system. 
# This page is the result of running Jocco against its own source file.
#
# If you install Jocco, you can run it from the command-line:
#
#     jocco src/*.coffee
#
# ...will generate an HTML documentation page for each of the named source files, 
# with a menu linking to the other pages, saving it into a `docs` folder.
#
# The [source for Jocco](http://github.com/dignifiedquire/jocco) is available on GitHub,
# and released under the MIT license.
#
# To install Jocco, first make sure you have [Node.js](http://nodejs.org/),
# [Pygments](http://pygments.org/) (install the latest dev version of Pygments
# from [its Mercurial repo](https://bitbucket.org/birkenfeld/pygments-main)), and
# [CoffeeScript](http://coffeescript.org/). Then, with NPM:
#
#     sudo npm install -g jocco
#
# Jocco can be used to process CoffeeScript, JavaScript, Ruby, Python, or TeX files.
# Only single-line comments are processed -- block comments are ignored.
#
#### Partners in Crime:
#
# * If **Node.js** doesn't run on your platform, or you'd prefer a more 
# convenient package, get [Ryan Tomayko](http://github.com/rtomayko)'s 
# [Rocco](http://rtomayko.github.com/rocco/rocco.html), the Ruby port that's 
# available as a gem. 
# 
# * If you're writing shell scripts, try
# [Shocco](http://rtomayko.github.com/shocco/), a port for the **POSIX shell**,
# also by Mr. Tomayko.
# 
# * If Python's more your speed, take a look at 
# [Nick Fitzgerald](http://github.com/fitzgen)'s [Pycco](http://fitzgen.github.com/pycco/). 
#
# * For **Clojure** fans, [Fogus](http://blog.fogus.me/)'s 
# [Marginalia](http://fogus.me/fun/marginalia/) is a bit of a departure from 
# "quick-and-dirty", but it'll get the job done.
#
# * **Lua** enthusiasts can get their fix with 
# [Robert Gieseke](https://github.com/rgieseke)'s [Locco](http://rgieseke.github.com/locco/).
# 
# * And if you happen to be a **.NET**
# aficionado, check out [Don Wilson](https://github.com/dontangg)'s 
# [Nocco](http://dontangg.github.com/nocco/).

#### Main Documentation Generation Functions

# Generate the documentation for a source file by reading it in, splitting it
# up into comment/code sections, highlighting them for the appropriate language,
# and merging them into an HTML template.
generateDocumentation = (source, config, callback) ->
  fs.readFile source, (error, buffer) ->
    throw error if error
    code = buffer.toString()
    sections = parse source, code
    highlight source, sections, ->
      generateHtml source, sections, config
      callback()

# Given a string of source code, parse out each comment and the code that
# follows it, and create an individual **section** for it.
# Sections take the form:
#
#     {
#       docsText: ...
#       docsHtml: ...
#       codeText: ...
#       codeHtml: ...
#     }
#
parse = (source, code) ->
  lines    = code.split '\n'
  sections = []
  language = getLanguage source
  hasCode  = docsText = codeText = ''

  save = (docsText, codeText) ->
    sections.push {docsText, codeText}

  for line in lines
    if line.match(language.commentMatcher) and not line.match(language.commentFilter)
      if hasCode
        save docsText, codeText
        hasCode = docsText = codeText = ''
      docsText += line.replace(language.commentMatcher, '') + '\n'
    else
      hasCode = yes
      codeText += line + '\n'
  save docsText, codeText
  sections

# Highlights parsed sections of code, using **Pygments** over stdio,
# and runs the text of their corresponding comments through **Markdown**, using
# [Showdown.js](https://github.com/coreyti/showdown).  If Pygments is not present
# on the system, output the code in plain text.
#
#
# We process all sections with single calls to Pygments and Showdown, by 
# inserting marker comments between them, and then splitting the result
# string wherever the marker occurs.
highlight = (source, sections, callback) ->
  language = getLanguage source
  pygments = spawn 'pygmentize', [
    '-l', language.name,
    '-f', 'html',
    '-O', 'encoding=utf-8,tabsize=2'
  ]
  output = ''
  code = (section.codeText for section in sections).join language.codeSplitText
  docs = (section.docsText for section in sections).join language.docsSplitText
  
  pygments.stderr.on 'data', ->
  pygments.stdin.on 'error', ->
  pygments.stdout.on 'data', (result) ->
    output += result if result
    
  pygments.on 'exit', ->
    output = output.replace(highlightStart, '').replace(highlightEnd, '')
    if output is ''
      codeFragments = (htmlEscape section.codeText for section in sections)
    else
      codeFragments = output.split language.codeSplitHtml
    docsFragments = showdown.makeHtml(docs).split language.docsSplitHtml
    
    for section, i in sections
      section.codeHtml = highlightStart + codeFragments[i] + highlightEnd
      section.docsHtml = docsFragments[i]
    callback()
    
  if pygments.stdin.writable
    pygments.stdin.write code
    pygments.stdin.end()
  
# Escape an html string, to produce valid non-highlighted output when pygments 
# is not present on the system.
htmlEscape = (string) -> 
  string.replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#x27;')
    .replace(/\//g,'&#x2F;')

# Once all of the code is finished highlighting, we can generate the HTML file by
# passing the completed sections into the template, and then writing the file to 
# the specified output path.
generateHtml = (source, sections, config) ->
  destination = (filepath) ->
    path.join(config.output, path.basename(filepath, path.extname(filepath)) + '.html')   
  title = path.basename source
  dest  = destination source
  html  = config.joccoTemplate {
    title      : title, 
    sections   : sections, 
    sources    : config.sources, 
    path       : path, 
    destination: destination
    css        : path.basename(config.css)
  }
  console.log "jocco: #{source} -> #{dest}"
  fs.writeFileSync dest, html

#### Helpers & Setup

# Require our external dependencies, including **Showdown.js**
# (the JavaScript implementation of Markdown).
fs       = require 'fs'
path     = require 'path'
showdown = require('./../vendor/showdown').Showdown
{spawn, exec} = require 'child_process'
commander = require 'commander'

# Read resource file and return its content.
getResource = (name) ->
  fullPath = path.join __dirname, '..', 'resources', name
  fs.readFileSync(fullPath).toString()

# Languages are stored in JSON format in the file `resources/languages.json`
# Each item maps the file extension to the name of the Pygments lexer and the
# symbol that indicates a comment. To add a new language, modify the file.
languages = JSON.parse getResource 'languages.json'

# Build out the appropriate matchers and delimiters for each language.
for ext, l of languages

  # Does the line begin with a comment?
  l.commentMatcher = ///^\s*#{l.symbol}\s?///

  # Ignore [hashbangs](http://en.wikipedia.org/wiki/Shebang_(Unix\))
  # and interpolations...
  l.commentFilter = /(^#![/]|^\s*#\{)/

  # The dividing token we feed into Pygments, to delimit the boundaries between
  # sections.
  l.codeSplitText = "\n#{l.symbol}DIVIDER\n"

  # The mirror of `codeSplitText` that we expect Pygments to return. We can split
  # on this to recover the original sections.
  # Note: the class is "c" for Python and "c1" for the other languages
  l.codeSplitHtml = ///\n*<span\sclass="c1?">#{l.symbol}DIVIDER<\/span>\n*///

  # The dividing token we feed into Showdown, to delimit the boundaries between
  # sections.
  l.docsSplitText = "\n##{l.name}DOCDIVIDER\n"

  # The mirror of `docsSplitText` that we expect Showdown to return. We can split
  # on this to recover the original sections.
  l.docsSplitHtml = ///<h1>#{l.name}DOCDIVIDER</h1>///

# Get the current language we're documenting, based on the extension.
getLanguage = (source) -> languages[path.extname(source)]

# Ensure that the destination directory exists.
ensureDirectory = (dir, cb, made=null) ->
  mode = parseInt '0777', 8
  fs.mkdir dir, mode, (er) ->
    return cb null, made || dir if not er
    if er.code == 'ENOENT'
      return ensureDirectory path.dirname(dir), (er, made) ->
        if er then cb er, made else ensureDirectory dir, cb, made
    cb er, made

# Micro-templating, originally by John Resig, borrowed by way of
# [Underscore.js](http://documentcloud.github.com/underscore/).
template = (str) ->
  new Function 'obj',
    'var p=[],print=function(){p.push.apply(p,arguments);};' +
    'with(obj){p.push(\'' +
    str.replace(/[\r\t\n]/g, " ")
       .replace(/'(?=[^<]*%>)/g,"\t")
       .split("'").join("\\'")
       .split("\t").join("'")
       .replace(/<%=(.+?)%>/g, "',$1,'")
       .split('<%').join("');")
       .split('%>').join("p.push('") +
       "');}return p.join('');"

# The start of each Pygments highlight block.
highlightStart = '<div class="highlight"><pre>'

# The end of each Pygments highlight block.
highlightEnd   = '</pre></div>'

# Extract the jocco version from `package.json`
version = JSON.parse(fs.readFileSync("#{__dirname}/../package.json")).version

# Default configuration options.
defaults =
  template: "#{__dirname}/../resources/jocco.jst"
  css     : "#{__dirname}/../resources/jocco.css"
  output  : "docs/"


# ### Run from Commandline
  
# Run Jocco from a set of command line arguments.  
#  
# 1. Parse command line using [Commander JS](https://github.com/visionmedia/commander.js).
# 2. Document sources, or print the usage help if none are specified.
run = (args=process.argv) ->
  commander.version(version)
    .usage("[options] <filePattern ...>")
    .option("-c, --css [file]","use a custom css file",defaults.css)
    .option("-o, --output [path]","use a custom output path",defaults.output)
    .option("-t, --template [file]","use a custom .jst template",defaults.template)
    .parse(args)
    .name = "jocco"
  if commander.args.length
    document(commander.args.slice(),commander)
  else
    console.log commander.helpInformation()

# ### Document Sources

# Run Jocco over a list of `sources` with the given `options`.
#  
# 1. Construct config to use by taking `defaults` first, then  merging in `options`
# 2. Generate the resolved source list, filtering out unknown types.
# 3. Load the specified template and css files.
# 4. Ensure the output path is created, write out the CSS file, 
# document each source, and invoke the completion callback if it is specified.
document = (sources, options = {}, callback = null) ->
  config = {}
  config[key] = defaults[key] for key,value of defaults
  config[key] = value for key,value of options if key of defaults

  resolved = []
  resolved = resolved.concat(resolveSource(src)) for src in sources
  config.sources = resolved.filter((source) -> getLanguage source).sort()
  console.log "jocco: skipped unknown type (#{m})" for m in resolved when m not in config.sources  
  
  config.joccoTemplate = template fs.readFileSync(config.template).toString()
  joccoStyles = fs.readFileSync(config.css).toString()

  ensureDirectory config.output, ->
    fs.writeFileSync path.join(config.output,path.basename(config.css)), joccoStyles
    files = config.sources.slice()
    nextFile = -> 
      callback() if callback? and not files.length
      generateDocumentation files.shift(), config, nextFile if files.length
    nextFile()

# ### Resolve Wildcard Source Inputs

# Resolve a wildcard `source` input to the files it matches.
#
# 1. If the input contains no wildcard characters, just return it.
# 2. Convert the wildcard match to a regular expression, and return
# an array of files in the path that match it.
resolveSource = (source) ->
  return source if not source.match(/([\*\?])/)
  regex_str = path.basename(source)
    .replace(/\./g, "\\$&")
    .replace(/\*/,".*")
    .replace(/\?/,".")
  regex = new RegExp('^(' + regex_str + ')$')
  file_path = path.dirname(source)
  files = fs.readdirSync file_path
  return (path.join(file_path,file) for file in files when file.match regex)

# ### Exports

# Information about jocco, and functions for programatic usage.
exports[key] = value for key, value of {
  run           : run
  document      : document
  parse         : parse
  resolveSource : resolveSource
  version       : version
  defaults      : defaults
  languages     : languages
  ensureDirectory: ensureDirectory
}
