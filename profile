# locale stuff
export LANG=en_AU.UTF-8
export LC_CTYPE=en_US.UTF-8

# general shell settings
export PS1='\u@\h:\w\$ ' # basic prompt. get's overwritten later
export FIGNORE="CVS:.DS_Store:.svn:__Alfresco.url"
export EDITOR='vim'
if [[ "$TERM_PROGRAM" =~ iTerm|Apple_Terminal ]] && [[ -x "`which mvim`" ]]; then
  export BUNDLER_EDITOR='mvim'
  export GEM_EDITOR='mvim'
fi
alias less='less -i'
export PAGER='less -SFXi'
export MAKEFLAGS='-j 3'
complete -d cd mkdir rmdir

# set CVS to use :ext: via SSH (preferring ssh-master if available)
if [ -x "`which ssh-master`" ]
then
  export CVS_RSH=ssh-master
else
  export CVS_RSH=ssh
fi

# open man pages in Preview.app
if [ -d "/Applications/Preview.app" ]
then
  pman () {
    man -t "$@" |
    ( which ps2pdf > /dev/null && ps2pdf - - || cat) |
    open -f -a /Applications/Preview.app
  }
fi

# our own bin dir at the highest priority, followed by /usr/local/bin
export PATH=~/bin:/usr/local/bin:/usr/local/sbin:"$PATH"

# add a poor facsimile for Linux's `free` if we're on Mac OS
if ! type free > /dev/null 2>&1 && [[ "$(uname -s)" == 'Darwin' ]]
then
  alias free="top -s 0 -l 1 -pid 0 -stats pid | grep '^PhysMem: ' | cut -d : -f 2- | tr ',' '\n'"
fi

# I love colour
if ls --version 2> /dev/null | grep -q 'GNU coreutils'
then
  export GREP_OPTIONS='--color=auto'
  alias ls="ls --color=auto --classify --block-size=\'1"
fi
alias dir='echo Use /bin/ls :\) >&2; false' # I used this to ween myself away from the 'dir' alias
alias mate='echo Use mvim :\) >&2; false'
alias nano='echo Use vim :\) >&2; false'

# helper for git aliases
function git_current_tracking()
{
  local BRANCH="$(git describe --contains --all HEAD)"
  local REMOTE="$(git config branch.$BRANCH.remote)"
  local MERGE="$(git config branch.$BRANCH.merge)"
  if [ -n "$REMOTE" -a -n "$MERGE" ]
  then
    echo "$REMOTE/$(echo "$MERGE" | sed 's#^refs/heads/##')"
  else
    echo "\"$BRANCH\" is not a tracking branch." >&2
    return 1
  fi
}

# git log patch
function glp()
{
  # don't use the pager if in word-diff mode
  local pager="$(echo "$*" | grep -q -- '--word-diff' && echo --no-pager)"

  # use reverse mode if we have a range
  local reverse="$(echo "$*" | grep -q '\.\.' && echo --reverse)"

  # if we have no non-option args then default to listing unpushed commits in reverse moode
  if ! (for ARG in "$@"; do echo "$ARG" | grep -v '^-'; done) | grep -q . && git_current_tracking > /dev/null 2>&1
  then
    local default_range="$(git_current_tracking)..HEAD"
    local reverse='--reverse'
  else
    local default_range=''
  fi

  git $pager log --patch $reverse "$@" $default_range
}

# git log file
function glf()
{
  git log --format=%H --follow -- "$@" | xargs --no-run-if-empty git show --stat
}

# git log search
function gls()
{
  local phrase="$1"
  shift
  if [[ $# == 0 ]]
  then
    local default_range=HEAD
  fi
  glp --pickaxe-all -S"$phrase" "$@" $default_range
}

function rake
{
  if [ -f Gemfile ]; then
    bundle exec rake "$@"
  else
    "$(which rake)" "$@"
  fi
}

function rails_command
{
  local cmd=$1
  shift

  if [ -e script/rails ]; then
    script/rails "$cmd" "$@"
  else
    "script/$cmd" "$@"
  fi
}

function __database_yml {
  if [[ -f config/database.yml ]]; then
    ruby -ryaml -rerb -e "puts YAML::load(ERB.new(IO.read('config/database.yml')).result)['${RAILS_ENV:-development}']['$1']"
  fi
}

function psql
{
  if [[ "$(__database_yml adapter)" == 'postgresql' ]]; then
    PGDATABASE="$(__database_yml database)" "$(which psql)" "$@"
    return $?
  fi
  "$(which psql)" "$@"
}
export PSQL_EDITOR='vim +"set syntax=sql"'

function mysql
{
  if [[ $# == 0 && "$(__database_yml adapter)" =~ 'mysql' ]]; then
    mysql -uroot "$(__database_yml database)"
    return $?
  fi
  "$(which mysql)" "$@"
}

# handy aliases
alias gl='git lg HEAD $(cd "$(git rev-parse --git-dir)" && find refs/{heads,remotes,tags} -type f)'
alias glw='glp --word-diff'
alias gco='git co'
alias gcp='git co -p'
alias gs='git status'
alias gst='git stash --include-untracked --keep-index'
alias gstp='git stash pop'
alias gd='git diff'
alias gdw='git --no-pager diff --color-words'
alias gds='gd --cached'
alias gdsw='gdw --cached'
alias gar='git reset HEAD'
alias garp='git reset -p HEAD'
alias gap='git add -p'
alias gau='git ls-files --other --exclude-standard -z | xargs -0 git add -Nv'
alias gaur='git ls-files --exclude-standard --modified -z | xargs -0 git ls-files --stage -z | gawk '\''BEGIN { RS="\0"; FS="\t"; ORS="\0" } { if ($1 ~ / e69de29bb2d1d6434b8b29ae775ad8c2e48c5391 /) { sub(/^[^\t]+\t/, "", $0); print } }'\'' | if git rev-parse --quiet --verify HEAD > /dev/null; then xargs --no-run-if-empty -0t -n 1 git reset -q -- 2>&1 | sed -e "s/^git reset -q -- /reset '\''/" -e "s/ *$/'\''/"; else xargs -0 -n 1 --no-run-if-empty git rm --cached --; fi'
alias gld="git fsck --lost-found | grep '^dangling commit' | cut -d ' ' -f 3- | xargs git show -s --format='%ct %H' | sort -nr | cut -d ' ' -f 2 | xargs git show --stat"
alias gc='git commit -v'
alias gca='gc --amend'
alias grt='git_current_tracking > /dev/null && git rebase -i $(git_current_tracking)'
alias gp='git push'
alias b='bundle'
alias bo='bundle open'
alias be='bundle exec'
alias ber='bundle exec $(egrep -q "^ {4}rails \(2\." Gemfile.lock && echo spec --format=nested --colour || echo rspec --format=doc) --drb'
alias bec='bundle exec cucumber --drb'
alias cuke='CUCUMBER_FORMAT=pretty bec'
alias besr='bundle exec spork rspec'
alias besc='bundle exec spork cucumber'
alias rc='pry -r ./config/environment'
alias rs='rails_command server'
alias cap='bundle exec cap'
alias timestamp='gawk "{now=strftime(\"%F %T \"); print now \$0; fflush(); }"'

# awesome history tracking
export HISTSIZE=100000
export HISTFILESIZE=100000
export HISTCONTROL=ignoredups
export HISTTIMEFORMAT="%Y-%m-%d %H:%M:%S  "
export PROMPT_COMMAND='history -a'
shopt -s histappend
PROMPT_COMMAND='history -a; echo "$$ $USER $(history 1)" >> ~/.bash_eternal_history'

# notify of bg job completion immediately
set -o notify

# use Vi mode instead of Emacs mode
set -o vi

# no mail notifications
shopt -u mailwarn
unset MAILCHECK

# check for window resizing whenever the prompt is displayed
shopt -s checkwinsize
# display "user@hostname: dir" in the window title
if [[ "$TERM" =~ ^xterm ]]
then
  export PROMPT_COMMAND="$PROMPT_COMMAND; "'echo -ne "\033]0;${USER}@${HOSTNAME}: ${PWD}\007"'
fi

# enable rvm if available
if [[ -s "$HOME/.rvm/scripts/rvm" ]]; then
  source "$HOME/.rvm/scripts/rvm"
elif [[ -s "/usr/local/rvm/scripts/rvm" ]]; then
  source "/usr/local/rvm/scripts/rvm"
fi
[[ -n "$rvm_path" ]] && [[ -r "$rvm_path/scripts/completion" ]] && source "$rvm_path/scripts/completion"
export rvm_pretty_print_flag=1

# set JAVA_HOME if on Mac OS
if [ -z "$JAVA_HOME" -a -d /System/Library/Frameworks/JavaVM.framework/Home ]
then
  export JAVA_HOME=/System/Library/Frameworks/JavaVM.framework/Home
fi

# lesspipe lets us do cool things like view gzipped files
if [ -x "`which lesspipe`" ]
then
  eval "$(lesspipe)"
elif [ -x "`which lesspipe.sh`" ]
then
  eval "$(lesspipe.sh)"
fi

# alias Debian's `ack-grep` to `ack`
if type -t ack-grep > /dev/null
then
  alias ack=ack-grep
fi

# load Homebrew's shell completion
if which brew > /dev/null && [ -f "$(brew --prefix)/Library/Contributions/brew_bash_completion.sh" ]
then
  source "$(brew --prefix)/Library/Contributions/brew_bash_completion.sh"
fi

function _bundle_spec_names() {
ruby <<-RUBY
  NAME_VERSION = '(?! )(.*?)(?: \(([^-]*)(?:-(.*))?\))?'
  File.open 'Gemfile.lock' do |io|
    in_specs = false
    io.lines.each do |line|
      line.chomp!
      case
      when in_specs && line == ''
        in_specs = false
      when line =~ /^ +specs:\$/
        in_specs = true
      when in_specs && line =~ %r{^ +#{NAME_VERSION}\$}
        puts \$1
      end
    end
  end
RUBY
}

function _bundle_open() {
  local curw
  COMPREPLY=()
  curw=${COMP_WORDS[COMP_CWORD]}
  COMPREPLY=($(compgen -W '$(_bundle_spec_names)' -- $curw));
  return 0
}
complete -F _bundle_open bo

function gup
{
  # subshell for `set -e` and `trap`
  (
    set -e # fail immediately if there's a problem

    # use `git-up` if installed
    if type git-up > /dev/null 2>&1
    then
      exec git-up
    fi

    # fetch upstream changes
    git fetch

    BRANCH=$(git describe --contains --all HEAD)
    if [ -z "$(git config branch.$BRANCH.remote)" -o -z "$(git config branch.$BRANCH.merge)" ]
    then
      echo "\"$BRANCH\" is not a tracking branch." >&2
      exit 1
    fi

    # create a temp file for capturing command output
    TEMPFILE="`mktemp -t gup.XXXXXX`"
    trap '{ rm -f "$TEMPFILE"; }' EXIT

    # if we're behind upstream, we need to update
    if git status | grep "# Your branch" > "$TEMPFILE"
    then

      # extract tracking branch from message
      UPSTREAM=$(cat "$TEMPFILE" | cut -d "'" -f 2)
      if [ -z "$UPSTREAM" ]
      then
        echo Could not detect upstream branch >&2
        exit 1
      fi

      # can we fast-forward?
      CAN_FF=1
      grep -q "can be fast-forwarded" "$TEMPFILE" || CAN_FF=0

      # stash any uncommitted changes
      git stash | tee "$TEMPFILE"
      [ "${PIPESTATUS[0]}" -eq 0 ] || exit 1

      # take note if anything was stashed
      HAVE_STASH=0
      grep -q "No local changes" "$TEMPFILE" || HAVE_STASH=1

      if [ "$CAN_FF" -ne 0 ]
      then
        # if nothing has changed locally, just fast foward.
        git merge --ff "$UPSTREAM"
      else
        # rebase our changes on top of upstream, but keep any merges
        git rebase -p "$UPSTREAM"
      fi

      # restore any stashed changes
      if [ "$HAVE_STASH" -ne 0 ]
      then
        git stash pop
      fi

    fi

  )
}

# `vimlast` opens the last modified file in Vim.
vimlast() {
  if [[ "$TERM_PROGRAM" == "iTerm.app" ]]; then
    local EDITOR=mvim
  fi
  FILE=$(
    /usr/bin/find ${1:-.} -type f \
      -not -regex '\./\..*' \
      -not -regex '\./tmp/.*' \
      -not -regex '\./log/.*' \
      -exec stat -c '%Y %n' {} +\; |
    sort -n | tail -1 | cut -d ' ' -f 2-
  )
  ${EDITOR:-vim} $FILE
}

# http://github.com/therubymug/hitch
hitch() {
  command hitch "$@"
  if [[ -s "$HOME/.hitch_export_authors" ]] ; then source "$HOME/.hitch_export_authors" ; fi
}
alias unhitch='hitch -u'

# filters for XML and JSON
alias xml='xmllint -format'
alias json='python -mjson.tool'

# be able to 'cd' into SMB URLs
# requires <http://github.com/jasoncodes/scripts/blob/master/smburl_to_path>
function cd_smburl()
{
  cd "`smburl_to_path "$1"`"
}

# begin awesome colour prompt..
export PS1=""

# add rvm version@gemset
if [[ -n "$rvm_path" ]]
then
  function __my_rvm_ps1()
  {
    [[ -z "$rvm_ruby_string" ]] && return
    if [[ -z "$rvm_gemset_name" && "$rvm_sticky_flag" -ne 1 ]]
    then
      [[ "$rvm_ruby_string" = "system" ]] && echo "system " && return
      grep -q -F "default=$rvm_ruby_string" "$rvm_path/config/alias" && return
    fi
    local full=$(
      "$rvm_path/bin/rvm-prompt" i v p g s |
      sed \
        -e 's/jruby-jruby-/jruby-/' -e 's/ruby-//' \
        -e 's/-head/H/' \
        -e 's/-2[0-9][0-9][0-9]\.[0-9][0-9]//' \
        -e 's/-@/@/' -e 's/-$//')
    [ -n "$full" ] && echo "$full "
  }
  export PS1="$PS1"'\[\033[01;30m\]$(__my_rvm_ps1)'
fi

# add user@host:path
export PS1="$PS1\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w"

function realpath()
{
  python -c 'import os,sys;print os.path.realpath(sys.argv[1])' "$@"
}

function first_file_match()
{
  local OP="$1"
  shift
  while [ $# -gt 0 ]
  do
    if [ $OP "$1" ]
    then
      echo "$1"
      return 0
    fi
    shift
  done
  return 1
}

# add git status if available
if which git > /dev/null
then
  GIT_COMPLETION_PATH="$(dirname $(realpath "$(which git)"))/../etc/bash_completion.d/git-completion.bash"
fi
if [ ! -f "$GIT_COMPLETION_PATH" ]
then
  GIT_COMPLETION_PATH=$(first_file_match -f \
    "/usr/local/git/contrib/completion/git-completion.bash" \
    "/opt/local/share/doc/git-core/contrib/completion/git-completion.bash" \
    "/etc/bash_completion.d/git" \
  )
fi
if [ -f "$GIT_COMPLETION_PATH" ]
then
  source "$GIT_COMPLETION_PATH"
  export GIT_PS1_SHOWDIRTYSTATE=1
  export GIT_PS1_SHOWSTASHSTATE=1
  export GIT_PS1_SHOWUNTRACKEDFILES=1
  export PS1="$PS1"'\[\033[01;30m\]$(__git_ps1 " (%s)")'
  complete -o bashdefault -o default -o nospace -F _git_log gl glp gls glw
  complete -o bashdefault -o default -o nospace -F _git_checkout gco gcp
  complete -o bashdefault -o default -o nospace -F _git_status gst
  complete -o bashdefault -o default -o nospace -F _git_diff gd gdw gds gdsw
  complete -o bashdefault -o default -o nospace -F _git_reset gar garp
  complete -o bashdefault -o default -o nospace -F _git_add gap
  complete -o bashdefault -o default -o nospace -F _git_commit gc gca
  complete -o bashdefault -o default -o nospace -F _git_push gp
  source ~/.dotfiles/git-flow-completion.bash
fi

# finish off the prompt
export PS1="$PS1"'\[\033[00m\]\$ '

# load local shell configuration if present
if [[ -f ~/.bashrc.local ]]
then
   source ~/.bashrc.local
fi
