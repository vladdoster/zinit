#!/usr/bin/env zsh
#
# Copyright (c) 2016-2020 Sebastian Gniazdowski and contributors
# Copyright (c) 2021-2022 zdharma-continuum and contributors

# FUNCTION: .zinit-any-colorify-as-uspl2 [[[
# Returns ANSI-colorified "user/plugin" string, from any supported
# plugin spec (user---plugin, user/plugin, user plugin, plugin).
#
# $1 - plugin spec (4 formats: user---plugin, user/plugin, user, plugin)
# $2 - plugin (only when $1 - i.e. user - given)
#
# $REPLY - ANSI-colorified "user/plugin" string
.zinit-any-colorify-as-uspl2() {
  .zinit-any-to-user-plugin "$1" "$2"
  local user="${reply[-2]}" plugin="${reply[-1]}"
  if [[ "$user" = "%" ]]; then
    .zinit-any-to-pid "" $plugin
    REPLY="${REPLY/https--github.com--(robbyrussell--oh-my-zsh|ohmyzsh--ohmyzsh)--trunk--plugins--/OMZP::}"
    REPLY="${REPLY/https--github.com--(robbyrussell--oh-my-zsh|ohmyzsh--ohmyzsh)--trunk--plugins/OMZP}"
    REPLY="${REPLY/https--github.com--(robbyrussell--oh-my-zsh|ohmyzsh--ohmyzsh)--trunk--lib--/OMZL::}"
    REPLY="${REPLY/https--github.com--(robbyrussell--oh-my-zsh|ohmyzsh--ohmyzsh)--trunk--lib/OMZL}"
    REPLY="${REPLY/https--github.com--(robbyrussell--oh-my-zsh|ohmyzsh--ohmyzsh)--trunk--themes--/OMZT::}"
    REPLY="${REPLY/https--github.com--(robbyrussell--oh-my-zsh|ohmyzsh--ohmyzsh)--trunk--themes/OMZT}"
    REPLY="${REPLY/https--github.com--(robbyrussell--oh-my-zsh|ohmyzsh--ohmyzsh)--trunk--/OMZ::}"
    REPLY="${REPLY/https--github.com--(robbyrussell--oh-my-zsh|ohmyzsh--ohmyzsh)--trunk/OMZ}"
    REPLY="${REPLY/https--github.com--sorin-ionescu--prezto--trunk--modules--/PZTM::}"
    REPLY="${REPLY/https--github.com--sorin-ionescu--prezto--trunk--modules/PZTM}"
    REPLY="${REPLY/https--github.com--sorin-ionescu--prezto--trunk--/PZT::}"
    REPLY="${REPLY/https--github.com--sorin-ionescu--prezto--trunk/PZT}"
    REPLY="${REPLY/(#b)%([A-Z]##)(#c0,1)(*)/%$ZINIT[col-uname]$match[1]$ZINIT[col-pname]$match[2]$ZINIT[col-rst]}"
  elif [[ $user == http(|s): ]]; then
    REPLY="${ZINIT[col-ice]}${user}/${plugin}${ZINIT[col-rst]}"
  else
    REPLY="${user:+${ZINIT[col-uname]}${user}${ZINIT[col-rst]}/}${ZINIT[col-pname]}${plugin}${ZINIT[col-rst]}"
  fi
} # ]]]
# FUNCTION: .zinit-compute-ice [[[
# Computes ICE array
#   - input
#   - static
#   - saved
# taking priorities into account.
# Can also pack resulting ices into ZINIT_SICE (see $2).
# Returns filepath to snippet directory and optional snippet file name (only
# valid if ICE[svn] is not set).
#
# $1 - URL (also plugin-spec)
# $2 - "pack" or "nopack" or "pack-nf" - packing means ICE
#      wins with static ice; "pack-nf" means that disk-ices will
#      be ignored (no-file?)
# $3 - name of output associative array, "ICE" is the default
# $4 - name of output string parameter, to hold path to directory ("local_dir")
# $5 - name of output string parameter, to hold filename ("filename")
# $6 - name of output string parameter, to hold is-snippet 0/1-bool ("is_snippet")
#
# $REPLY - snippet directory filepath
.zinit-compute-ice() {
  builtin emulate -LR zsh ${=${options[xtrace]:#off}:+-o xtrace}
  setopt extendedglob typesetsilent warncreateglobal noshortloops

  local ___URL="${1%/}" ___pack="$2" ___is_snippet=0
  local ___var_name1="${3:-ZINIT_ICE}" ___var_name2="${4:-local_dir}" ___var_name3="${5:-filename}" ___var_name4="${6:-is_snippet}"

  # Copy from .zinit-recall
  local -a ice_order nval_ices
  ice_order=(
    ${(s.|.)ZINIT[ice-list]}
    # include all additional ices – after stripping them from the possible: ''
    ${(@)${(@Akons:|:)${ZINIT_EXTS[ice-mods]//\'\'/}}/(#s)<->-/}
  )
  nval_ices=(
    ${(s.|.)ZINIT[nval-ice-list]}
    # include only those additional ices, don't have the '' in their name, i.e.
    # aren't designed to hold value
    ${(@)${(@)${(@Akons:|:)ZINIT_EXTS[ice-mods]}:#*\'\'*}/(#s)<->-/}
    svn
  )

  # strip whitespace from beginning of url
  ___URL="${${___URL#"${___URL%%[! $'\t']*}"}%/}"

  # snippet
  .zinit-two-paths "$___URL"
  local ___s_path="${reply[-4]}" ___s_svn="${reply[-3]}" ___path="${reply[-2]}" ___filename="${reply[-1]}" ___local_dir

  if [[ -d "$___s_path" || -d "$___path" ]]; then
    ___is_snippet=1
  else
    # plugin
    .zinit-any-to-user-plugin "$___URL" ""
    local ___user="${reply[-2]}" ___plugin="${reply[-1]}"
    ___s_path="" ___filename=""
    [[ "$___user" = "%" ]] && ___path="$___plugin" || ___path="${ZINIT[PLUGINS_DIR]}/${___user:+${___user}---}${___plugin//\//---}"
    .zinit-exists-physically-message "$___user" "$___plugin" || return 1
  fi

  [[ $___pack = pack* ]] && (( ${#ICE} > 0 )) && .zinit-pack-ice "${___user-$___URL}" "$___plugin"

  local -A ___sice
  local -a ___tmp

  ___tmp=( "${(z@)ZINIT_SICE[${___user-$___URL}${${___user:#(%|/)*}:+/}$___plugin]}" )
  (( ${#___tmp[@]} > 1 && ${#___tmp[@]} % 2 == 0 )) && ___sice=( "${(Q)___tmp[@]}" )

  if [[ "${+___sice[svn]}" = "1" || -n "$___s_svn" ]]; then
    if (( !___is_snippet && ${+___sice[svn]} == 1 )); then
      builtin print -r -- "The \`svn' ice is given, but the argument ($___URL) is a plugin"
      builtin print -r -- "(\`svn' can be used only with snippets)"
      return 1
    elif (( !___is_snippet )); then
      builtin print -r -- "Undefined behavior #1 occurred, please report at https://github.com/zdharma-continuum/zinit/issues"
      return 1
    fi
    if [[ -e "$___s_path" && -n "$___s_svn" ]]; then
      ___sice[svn]=""
      ___local_dir="$___s_path"
    else
      if [[ ! -e "$___path" ]] { 
        builtin print -r -- "No such snippet, looked at paths (1): $___s_path, and: $___path";
        return 1;
      }
      unset '___sice[svn]'
      ___local_dir="$___path"
    fi
  else
    if [[ -e "$___path" ]]; then
      unset '___sice[svn]'
      ___local_dir="$___path"
    else
      builtin print -r -- "No such snippet, looked at paths (2): $___s_path, and: $___path"
      return 1
    fi
  fi

  local ___zinit_path="$___local_dir/._zinit"
  # read disk-ice
  local -A ___mdata
  local ___key

  {
    for ___key in mode url is_release is_release{2..5} ${ice_order[@]}; do
      [[ -f "$___zinit_path/$___key" ]] && ___mdata[$___key]="$(<$___zinit_path/$___key)"
    done
    [[ "${___mdata[mode]}" = "1" ]] && ___mdata[svn]=""
  } 2>/dev/null

  # handle flag-ices; svn must be last
  for ___key in ${ice_order[@]}; do
    [[ $___key == (no|)compile ]] && continue

    if (( 0 == ${+ICE[no$___key]} && 0 == ${+___sice[no$___key]} )) {
      continue
    }
    # "If there is such ice currently, and there's no no* ice given, and
    # there's the no* ice in the static ice" – skip, don't unset. With
    # conjunction with the previous line this has the proper meaning: uset if
    # at least in one – current or static – ice there is the no* ice unless it
    # is the only in the static ice (unless there's on such ice "anyway").
    if (( 1 == ${+ICE[$___key]} && 0 == ${+ICE[no$___key]} && 1 == ${+___sice[no$___key]} )) {
      continue
    }

    if [[ "$___key" = "svn" ]]; then
      command builtin print -r -- "0" >! "$___zinit_path/mode"
      ___mdata[mode]=0
    else
      command rm -f -- "$___zinit_path/$___key"
    fi

    unset "___mdata[$___key]" "___sice[$___key]" "ICE[$___key]"
  done

  # final decision, static ice vs. saved ice
  local -A ___MY_ICE
  for ___key in mode url is_release is_release{2..5} ${ice_order[@]}; do
    # The second sum is: if the pack is *not* pack-nf, then depending on the
    # disk availability, otherwise: no disk ice
    (( ${+___sice[$___key]} + ${${${___pack:#pack-nf*}:+${+___mdata[$___key]}}:-0} )) && ___MY_ICE[$___key]="${___sice[$___key]-${___mdata[$___key]}}"
  done
  # One more round for the special case – update, which ALWAYS needs the teleid
  # from the disk or static ice
  ___key=teleid; [[ "$___pack" = pack-nftid ]] && {
    (( ${+___sice[$___key]} + ${+___mdata[$___key]} )) && ___MY_ICE[$___key]="${___sice[$___key]-${___mdata[$___key]}}"
  }

  : ${(PA)___var_name1::="${(kv)___MY_ICE[@]}"}
  : ${(P)___var_name2::=$___local_dir}
  : ${(P)___var_name3::=$___filename}
  : ${(P)___var_name4::=$___is_snippet}

  return 0
} # ]]]
# FUNCTION: .zinit-countdown [[[
# Displays a countdown 5...4... etc.
#
# $REPLY - 1 if Ctrl-C is pressed, otherwise 0
.zinit-countdown() {
  (( !${+ICE[countdown]} )) && return 0

  builtin emulate -L zsh -o extendedglob ${=${options[xtrace]:#off}:+-o xtrace}
  trap "+zi-log \"{ehi}ABORTING, the ice {ice}$ice{ehi} not ran{rst}\"; return 1" INT

  local count=5 ice tpe="$1"

  ice="${ICE[$tpe]}"
  [[ $tpe = "atpull" && $ice = "%atclone" ]] && ice="${ICE[atclone]}"
  ice="{b}{ice}$tpe{ehi}:{rst}${ice//(#b)(\{[a-z0-9…–_-]##\})/\\$match[1]}"

  +zi-log -n "{hi}Running $ice{rst}{hi} ice in...{rst} "

  while (( -- count + 1 )) {
    +zi-log -n -- "{b}{error}"$(( count + 1 ))"{rst}{…}"
    sleep 1
  }

  +zi-log -r -- "{b}{error}0 <running now>{rst}{…}"
  return 0
} # ]]]
# FUNCTION: .zinit-exists-physically [[[
# Checks if directory of given plugin exists in PLUGIN_DIR.
#
# $1 - plugin spec (4 formats: user---plugin, user/plugin, user, plugin)
# $2 - plugin (only when $1 - i.e. user - given)
.zinit-exists-physically() {
  .zinit-any-to-user-plugin "$1" "$2"
  if [[ ${reply[-2]} = % ]]; then
    [[ -d ${reply[-1]} ]] && return 0 || return 1
  else
    [[ -d ${ZINIT[PLUGINS_DIR]}/${reply[-2]:+${reply[-2]}---}${reply[-1]//\//---} ]] \
      && return 0 \
      || return 1
  fi
} # ]]]
# FUNCTION: .zinit-exists-physically-message [[[
# Checks if directory of given plugin exists in PLUGIN_DIR, and outputs error
# message if it doesn't.
#
# $1 - plugin spec (4 formats: user---plugin, user/plugin, user, plugin)
# $2 - plugin (only when $1 - i.e. user - given)
.zinit-exists-physically-message() {
  builtin emulate -LR zsh ${=${options[xtrace]:#off}:+-o xtrace}
  builtin setopt extendedglob warncreateglobal typesetsilent noshortloops rcquotes
  if ! .zinit-exists-physically "$1" "$2"; then
    .zinit-any-to-user-plugin "$1" "$2"
    if [[ $reply[1] = % ]]; then
      .zinit-any-to-pid "$1" "$2"
      local spec1=$REPLY
      if [[ $1 = %* ]]; then
        local spec2=%${1#%}${${1#%}:+${2:+/}}$2
      elif [[ -z $1 || -z $2 ]]; then
        local spec3=%${1#%}${2#%}
      fi
    else
      integer nospec=1
    fi
    .zinit-any-colorify-as-uspl2 "$1" "$2"

    +zi-log "{error}No such (plugin or snippet){rst}: $REPLY."

    [[ $nospec -eq 0 && $spec1 != $spec2 ]] \
      && +zi-log "(expands to: {file}${spec2#%}{rst})."

    return 1
  fi
  return 0
} # ]]]
# FUNCTION: .zinit-find-completion-candidates [[[
# Scans a directory tree for files that Zsh's completion system would accept as
# completion functions. This is THE single place where BOTH halves of the
# decision live - *whether* a file is a completion, and *under what name* it is
# installed into ${ZINIT[COMPLETIONS_DIR]}; every other site calls this instead
# of open-coding a glob, so that `creinstall', `cuninstall', `report', `csearch'
# and `zstatus' can never disagree with each other.
#
# Two kinds of file qualify:
#
#   _name       a conventionally named completion; installed as `_name'. Under
#               `validate' its first line must be `#compdef' or `#autoload' (see
#               ZINIT[COMPLETIONS_STRICT]).
#
#   name.zsh    a completion shipped under a name `compinit' would never pick up
#   name.compdef  on its own, e.g. `pnpm-shell-completion.plugin.zsh' or
#   name-completion  `hub.zsh_completion'. It qualifies only if its first line is
#               `#compdef <cmd> …', and is installed as `_<cmd>' - the very name
#               `compinit' would have bound it to. This arm is ALWAYS
#               content-checked, `validate' or not: without the tag there is no
#               name to derive. Switch it off with
#               `zstyle :zinit:config completion-derive-names no'.
#
# Rejects, in order:
#   - anything that is not a plain file after resolving symlinks - the (-.)
#     qualifier. This drops directories (e.g. a plugin's tests/_output), symlinks
#     to directories, dangling symlinks, fifos, sockets and devices, while
#     keeping the legitimate case of a completion shipped as a symlink to a
#     regular file. `(^/)' keeps symlinked directories and `(.)' drops symlinked
#     files - neither is correct on its own.
#   - names matching ${ZINIT[COMPLETION_IGNORE]} (plus …_EXTRA), matched against
#     the whole path.
#   - anything under a directory named in ${ZINIT[COMPLETION_IGNORE_DIRS]},
#     matched against the path RELATIVE to $1 (empty by default).
#   - a derived name colliding with another candidate's: first match wins, and
#     since the `_name' files are emitted first, a real `_foo' always beats a
#     `foo.zsh' that merely says `#compdef foo'.
#
# $1 - directory to scan
# $2 - the literal word `validate' to additionally content-check the `_name'
#      files
#
# $reply  - the candidate completion files. Under `validate' with
#           ZINIT[COMPLETIONS_STRICT] set, the untagged `_name' ones are removed.
# $reply2 - `_name' candidates whose first line is not `#compdef'/`#autoload'.
#           Always emptied; only ever filled when $2 = validate. Files rejected
#           by the second arm are NOT listed here - they are ordinary files that
#           merely happened to match the glob, not completions gone wrong.
# $reply3 - the install name of each $reply entry, at the same index.
.zinit-find-completion-candidates() {
  builtin emulate -LR zsh ${=${options[xtrace]:#off}:+-o xtrace}
  builtin setopt extendedglob nullglob typesetsilent warncreateglobal noshortloops

  typeset -ga reply reply2 reply3
  local __dir=${1%/} __ign __pat __c __rel __raw __first __name
  local -a __w __cands __keep __a __a_ok __b __b_names
  integer __i __und

  reply=( ) reply2=( ) reply3=( )
  [[ -z $__dir ]] && return 0

  __ign=${ZINIT[COMPLETION_IGNORE]}${ZINIT[COMPLETION_IGNORE_EXTRA]:+\|${ZINIT[COMPLETION_IGNORE_EXTRA]}}
  # One tree walk for both arms - `**' over a plugin directory is the expensive
  # part, and doing it twice would double it. The arms are told apart by the
  # leading underscore in the loop below. `*[-_]completion' already covers
  # `*.zsh-completion' and `*.zsh_completion'.
  # No `D': a completion never lives in a dot-directory, and descending into
  # them is 55% of this function's runtime (.git alone triples the entry count).
  # It also keeps `._backup', where ziextract stashes displaced files, from
  # resurrecting a stale completion. `~*/.git/*' is NOT an alternative - zsh
  # applies `~' after the walk, so it prunes nothing.
  __pat='_[^_.]*'
  [[ ${ZINIT[COMPLETION_DERIVE_NAMES]} == (1|true|on|yes) ]] && \
    __pat+='|*.zsh|*[-_]completion|*.compdef'
  __cands=( $__dir/**/(${~__pat})~*(${~__ign})(N-.) )

  # Anchored directory-name filter. The path is stripped by index rather than
  # with ${__c#$__dir}, because the latter would treat $__dir as a pattern.
  if [[ -n ${ZINIT[COMPLETION_IGNORE_DIRS]} ]]; then
    for __c in $__cands; do
      __rel=${__c[${#__dir}+2,-1]}
      [[ /$__rel == */(${~ZINIT[COMPLETION_IGNORE_DIRS]})/* ]] && continue
      __keep+=( $__c )
    done
    __cands=( $__keep )
  fi

  # Mirrors what compinit itself does when it walks $fpath: split the first line
  # on space/tab and look at word one. `read -k 64' bounds the read, so a
  # multi-megabyte single-line file cannot be slurped; it also copes with an
  # empty file, a missing trailing newline, embedded NULs, and an unreadable or
  # vanished file (non-zero return, $__raw stays empty). It is a builtin read -
  # never `head' - because this runs once per candidate file.
  for __c in $__cands; do
    __und=0
    [[ ${__c:t} == _* ]] && { __und=1; __a+=( $__c ) }
    (( __und )) && [[ $2 != validate ]] && continue

    __raw=
    { read -r -k 64 -u 0 __raw } < $__c 2>/dev/null
    __first=${__raw%%$'\n'*}
    __w=( ${${(s: :)${${__first//$'\t'/ }##[[:blank:]]#}}:#} )

    if (( __und )); then
      if [[ ${__w[1]} == (\#compdef|\#autoload) ]]; then
        __a_ok+=( $__c )
      else
        reply2+=( $__c )
      fi
    elif [[ ${__w[1]} == \#compdef ]]; then
      # `#compdef -p <pattern>' and the -P/-k/-K/-N/-a forms name no single
      # command, so there is nothing to derive a filename from.
      __name=${__w[2]}
      [[ -z $__name || $__name == -* || $__name == *[][/=*?]* ]] && continue
      # Only the first command word: `#compdef gcc g++ cc' installs as `_gcc',
      # and compinit binds the rest itself by re-reading the very same line.
      __b+=( $__c ) __b_names+=( _$__name )
    fi
  done

  [[ $2 = validate && ${ZINIT[COMPLETIONS_STRICT]} == (1|true|on|yes) ]] && __a=( $__a_ok )

  # reply3 is the install name of reply at the same index; for the `_name' arm
  # that is just the basename, so it is derived rather than carried.
  reply=( $__a ) reply3=( ${__a[@]:t} )
  for (( __i = 1; __i <= $#__b; __i ++ )); do
    (( ${reply3[(Ie)${__b_names[__i]}]} )) && continue
    reply+=( ${__b[__i]} ) reply3+=( ${__b_names[__i]} )
  done

  return 0
} # ]]]
# FUNCTION: .zinit-first [[[
# Finds the main file of plugin. There are multiple file name formats, they are
# ordered in order starting from more correct ones, and matched.
# .zinit-load-plugin() has similar code parts and doesn't call .zinit-first() –
# for performance. Obscure matching is done in .zinit-find-other-matches, here
# and in .zinit-load(). Obscure = non-standard main-file naming convention.
#
# $1 - plugin spec (4 formats: user---plugin, user/plugin, user, plugin)
# $2 - plugin (only when $1 - i.e. user - given)
.zinit-first() {
  .zinit-any-to-user-plugin "$1" "$2"
  local user="${reply[-2]}" plugin="${reply[-1]}"

  .zinit-any-to-pid "$1" "$2"
  .zinit-get-object-path plugin "$REPLY"
  integer ret=$?
  local dname="$REPLY"
  (( ret )) && { reply=( "$dname" "" ); return 1; }

  # look for file to compile - first look for the most common one (optimization)
  # then for other possibilities
  if [[ -e "$dname/$plugin.plugin.zsh" ]]; then
    reply=( "$dname/$plugin.plugin.zsh" )
  else
    .zinit-find-other-matches "$dname" "$plugin"
  fi

  if [[ "${#reply}" -eq "0" ]]; then
    reply=( "$dname" "" )
    return 1
  fi

  # take first entry (ksharrays resilience)
  reply=( "$dname" "${reply[-${#reply}]}" )
  return 0
} # ]]]
# FUNCTION: .zinit-store-ices [[[
# Saves ice mods in given hash onto disk.
#
# $1 - directory where to create or delete files
# $2 - name of hash that holds values
# $3 - additional keys of hash to store, space separated
# $4 - additional keys of hash to store, empty-meaningful ices, space separated
# $5 – URL, if applicable
# $6 – mode, svn=1, 0=single file
.zinit-store-ices() {
  local ___pfx="$1" ___ice_var="$2" ___add_ices="$3" ___add_ices2="$4"
  local url="$5" mode="$6"

  # Copy from zinit-recall response
  local -a ice_order nval_ices
  ice_order=(
    ${(s.|.)ZINIT[ice-list]}
    # include all additional ices – after stripping them from the possible: ''
    ${(@)${(@Akons:|:)${ZINIT_EXTS[ice-mods]//\'\'/}}/(#s)<->-/}
  )
  nval_ices=(
    ${(s.|.)ZINIT[nval-ice-list]}
    # include only those additional ices, don't have the '' in their name, i.e.
    # aren't designed to hold value
    ${(@)${(@)${(@Akons:|:)ZINIT_EXTS[ice-mods]}:#*\'\'*}/(#s)<->-/}
    # must be last
    svn
  )

  command mkdir -p "$___pfx" && echo '*' > "$___pfx/.gitignore"
  local ___key ___var_name
  # No nval_ices here
  for ___key in ${ice_order[@]:#(${(~j:|:)nval_ices[@]})} ${(s: :)___add_ices[@]}; do
    ___var_name="${___ice_var}[$___key]"
    (( ${(P)+___var_name} )) && builtin print -r -- "${(P)___var_name}" >! "$___pfx"/"$___key"
  done

  # Ices that even empty mean something
  for ___key in ${nval_ices[@]} ${(s: :)___add_ices2[@]}; do
    ___var_name="${___ice_var}[$___key]"
    if (( ${(P)+___var_name} )); then
      builtin print -r -- "${(P)___var_name}" >! "$___pfx"/"$___key"
    else
      command rm -f "$___pfx"/"$___key"
    fi
  done

  # url and mode are declared at the beginning of the body
  for ___key in url mode; do
    [[ -n "${(P)___key}" ]] && builtin print -r -- "${(P)___key}" >! "$___pfx"/"$___key"
  done
} # ]]]
# FUNCTION: .zinit-two-paths [[[
# Obtains a snippet URL without specification if it is an SVN URL (points to
# directory) or regular URL (points to file), returns 2 possible paths for
# further examination
#
# $REPLY - two filepaths
.zinit-two-paths() {
  builtin emulate -LR zsh ${=${options[xtrace]:#off}:+-o xtrace}
  setopt extendedglob typesetsilent warncreateglobal noshortloops

  local dirnameA dirnameB local_dirA local_dirB svn_dirA url1 url2 url=$1
  local -a fileB_there

  # remove leading whitespace and trailing /
  url="${${url#"${url%%[! $'\t']*}"}%/}"
  url1=$url
  url2=$url

  .zinit-get-object-path snippet "$url1"
  local_dirA=$reply[-3] dirnameA=$reply[-2]
  [[ -d "$local_dirA/$dirnameA/.svn" ]] && {
    svn_dirA=".svn"
    if { .zinit-first % "$local_dirA/$dirnameA"; } {
      fileB_there=( ${reply[-1]} )
    }
  }

  .zinit-get-object-path snippet "$url2"
  local_dirB=$reply[-3] dirnameB=$reply[-2]

  [[ -z $svn_dirA ]] && fileB_there=( "$local_dirB/$dirnameB"/*~*.(zwc|md|js|html)(.-DOnN[1]) )

  reply=( "$local_dirA/$dirnameA" "$svn_dirA" "$local_dirB/$dirnameB" "${fileB_there[1]##$local_dirB/$dirnameB/#}" )
} # ]]]

# Local Variables:
# mode: Shell-Script
# sh-indentation: 2
# indent-tabs-mode: nil
# sh-basic-offset: 2
# End:
# vim: ft=zsh sw=2 ts=2 et foldmarker=[[[,]]] foldmethod=marker
