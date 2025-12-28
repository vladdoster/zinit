#!/usr/bin/env zsh
# -*- mode: sh; sh-indentation: 4; indent-tabs-mode: nil; sh-basic-offset: 4; -*-
# Copyright (c) 2025 Zinit contributors.

# FUNCTION: +zi-execute [[[
# Execute command with optional silence flag
# Usage: +zi-execute [--silent] command args...
# Note: Uses eval to execute arbitrary commands - this is intentional
# to support complex command strings with pipes, redirections, etc.
+zi-execute() {
    builtin emulate -LR zsh ${=${options[xtrace]:#off}:+-o xtrace}
    setopt extendedglob warncreateglobal typesetsilent noshortloops
    
    local -a o_silent
    zmodload zsh/zutil
    zparseopts -D -F -K -- \
        {s,-silent}=o_silent \
    || return 1
    
    # Check if we have any arguments left
    if (( $# == 0 )); then
        print -u2 "Error: No command specified"
        return 1
    fi
    
    # Combine all remaining arguments into a single command string
    local cmd="$*"
    
    # Log the command that will be executed
    +zi-log "{ice}Executing:{rst} $cmd"
    
    # Execute the command
    if (( $#o_silent )); then
        # Silent mode: suppress output
        eval "$cmd" &>/dev/null
    else
        # Normal mode: show output
        eval "$cmd"
    fi
    
    # Return the exit status of the command
    return $?
} # ]]]

# FUNCTION: gh-clone-build [[[
# Clone a GitHub repository, detect build system (make, cmake, or autotools),
# configure, build, and install the project with optional custom prefix.
#
# Usage:
#   gh-clone-build [options] <repository>
#
# Options:
#   -h, --help              Show this help message
#   -v, --verbose           Enable verbose output
#   -p, --prefix <path>     Set custom installation prefix (default: /usr/local)
#
# Arguments:
#   repository              GitHub repository in format 'owner/repo' or full URL
#
# Examples:
#   gh-clone-build --prefix ~/.local neovim/neovim
#   gh-clone-build -v --prefix /opt/tools vim/vim
#   gh-clone-build https://github.com/tmux/tmux
#
gh-clone-build() {
    builtin emulate -LR zsh
    setopt extendedglob warncreateglobal typesetsilent noshortloops

    local -a o_help o_verbose o_prefix
    local repository repo_url repo_name clone_dir build_system prefix_path verbose_output
    local -i verbose=1

    # Usage message
    local -a usage=(
        'Usage:'
        '  gh-clone-build [options] <repository>'
        ''
        'Options:'
        '  -h, --help              Show this help message'
        '  -v, --verbose           Enable verbose output'
        '  -p, --prefix <path>     Set custom installation prefix (default: /usr/local)'
        ''
        'Arguments:'
        '  repository              GitHub repository in format "owner/repo" or full URL'
        ''
        'Examples:'
        '  gh-clone-build --prefix ~/.local neovim/neovim'
        '  gh-clone-build -v --prefix /opt/tools vim/vim'
        '  gh-clone-build https://github.com/tmux/tmux'
    )

    # Parse options using zparseopts
    zmodload zsh/zutil
    zparseopts -D -F -K -- \
        {h,-help}=o_help \
        {v,-verbose}=o_verbose \
        {p,-prefix}:=o_prefix \
    || {
        print -l -- $usage
        return 1
    }

    # Show help if requested
    if (( $#o_help )); then
        print -l -- $usage
        return 0
    fi

    # Set verbose mode
    (( $#o_verbose )) || { 
        verbose=1
    }

    # Set prefix path
    if (( $#o_prefix )); then
        prefix_path="${o_prefix[2]}"
        # Expand ~ to home directory
        prefix_path="${prefix_path/#\~/$HOME}"
    else
        prefix_path="${ZINIT[HOME_DIR]}/polaris"
        mkdir -p $prefix_path
    fi
    prefix_path="${ZINIT[HOME_DIR]}"

    # Check if repository argument is provided
    if (( $# == 0 )); then
        print "Error: repository argument is required" >&2
        print -l -- ${usage}
        return 1
    fi

    # Create temporary directory for cloning
    clone_dir=${ZINIT[PLUGINS_DIR]}
    if [[ ! -d ${clone_dir} ]]; then
        print "Error: Failed to create temporary directory" >&2
        return 1
    fi

    repository="$1"
    local -i local_repo_path=0
    # Normalize repository URL
    if [[ $repository == https://* ]] || [[ $repository == git@* ]] || [[ $repository == git://* ]]; then
        repo_url="$repository"
        # Extract repository name from URL
        repo_name="${repository:t:r}"
    elif [[ -d ${repository:A:h} ]]; then
         # Change to repository directory
         local_repo_path=1
         cd "${repository:A}" || {
             print "Error: Failed to enter repository directory" >&2
             return 1
          }
          # Local directory path
          repo_url="$repository"
          repo_name="${repository:t}"
    elif [[ $repository == */* ]] && [[ $repository != /* ]]; then
        # Format: owner/repo (GitHub shorthand)
        repo_url="https://github.com/${repository}.git"
        repo_name="${repository:t}"
    else
        print "Error: Invalid repository format. Use 'owner/repo', full URL, or local path" >&2
        return 1
    fi

    (( verbose )) && print "Repository URL: $repo_url"
    (( verbose )) && print "Repository name: $repo_name"
    (( verbose )) && print "Installation prefix: $prefix_path"
    (( verbose )) && print "Clone directory: $clone_dir"

    # Cleanup function

    if (( local_repo_path == 0 )); then
      # Clone repository
      print -- "> Cloning repository: ${repository}"
      if (( verbose )); then
          git clone "${repo_url}" "${clone_dir}/${repo_name}" || {
              print "Error: Failed to clone ${repo_name} repository" >&2
              return 1
          }
      else
          git clone -q "${repo_url}" "${clone_dir}/${repo_name}" 2>/dev/null || {
              print "Error: Failed to clone ${repo_name} repository" >&2
              return 1
          }
      fi

      # Change to repository directory
      cd "${clone_dir}/${repo_name}" || {
          print "Error: Failed to enter repository directory" >&2
          return 1
      }
    fi

    print -- "> Detecting build system..."

    # Detect build system
    if [[ -f CMakeLists.txt ]]; then
        build_system="cmake"
        (( verbose )) && print -- "== Detected CMake build system"
    elif [[ ( -f configure.(in|ac) || -f configure ) ]]; then
        build_system="autotools"
        (( verbose )) && print -- "== Detected Autotools build system"
    elif [[ -n Makefile*(#qN) ]]; then
        build_system="make"
        (( verbose )) && print -- "== Detected Make build system"
    else
        print "Error: Could not detect build system (no CMakeLists.txt, Makefile, or configure.ac found)" >&2
        return 1
    fi

    # Configure and build based on detected build system
    case $build_system in
        cmake)
            print -- "> Configuring with CMake..."
            mkdir -p build && cd build || {
                print "Error: Failed to create build directory" >&2
                return 1
            }

            if (( verbose )); then
                cmake -DCMAKE_INSTALL_PREFIX="$prefix_path" .. || {
                    print "Error: CMake configuration failed" >&2
                    return 1
                }
            else
                cmake -DCMAKE_INSTALL_PREFIX="$prefix_path" .. >/dev/null 2>&1 || {
                    print "Error: CMake configuration failed" >&2
                    return 1
                }
            fi

            print -- "> Building with CMake..."
            if (( verbose )); then
                cmake --build . || {
                    print "Error: CMake build failed" >&2
                    return 1
                }
            else
                cmake --build . >/dev/null 2>&1 || {
                    print "Error: CMake build failed" >&2
                    return 1
                }
            fi

            print -- "> Installing to: $prefix_path"
            if (( verbose )); then
                cmake --install . || {
                    print "Error: CMake install failed" >&2
                    return 1
                }
            else
                cmake --install . >/dev/null 2>&1 || {
                    print "Error: CMake install failed" >&2
                    return 1
                }
            fi
            ;;

        autotools)
            print -- "> Configuring with Autotools..."
            
            # Generate configure script if it doesn't exist
            if [[ ! -f configure ]]; then
                if [[ -f autogen.sh ]]; then
                    (( verbose )) && print -- "== running autogen.sh..."
                    { +zi-execute sh ./autogen.sh } || {
                        print "Error: autogen.sh failed" >&2
                        return 1
                    }
                elif command -v autoreconf >/dev/null 2>&1; then
                    (( verbose )) && print -- "== running autoreconf..."
                    { +zi-execute autoreconf -i } || {
                        print "Error: autoreconf failed" >&2
                        return 1
                    }
                else
                    print "Error: configure script not found and cannot generate it" >&2
                    return 1
                fi
            fi

            { 
                +zi-log "== running {ice}./configure --prefix=${prefix_path}{rst}..."
                +zi-execute "./configure" --prefix="${prefix_path}"
            } || {
                print "Error: configure failed" >&2
                return 1
            }
            ;&

        make)
            print -- "= Building with Make..."
            
            # Check if Makefile has install target and PREFIX support
            local has_install=0 has_prefix=0 makefile_name=""
            local valid_makefile_names="(GNU|)[mM]akefile"
            makefile_name=$~valid_makefile_names
            local -a makefiles=(*[mM]akefile(NY1)) 
            +zi-log "== found ${#makefiles} Makefiles: {ice}${makefiles}{rst}"
            if [[ -n $makefile_name ]]; then
                has_install=1
                has_prefix=1
                if grep -q "PREFIX" "$makefile_name" 2>/dev/null; then
                    has_prefix=1
                fi
            fi
            has_prefix=1
            if (( has_prefix )); then
                if (( has_prefix )); then
                    { 
                        +zi-execute make PREFIX="$prefix_path"
                    } || {
                        print "Error: make build failed" >&2
                        return 1
                    }
                else
                    {
                        +zi-execute make PREFIX="$prefix_path"
                    } || {
                        print "Error: make build failed" >&2
                        return 1
                    }
                fi
                if (( has_prefix )); then 
                    {
                        print -- "== Installing to custom prefix: ${(D)prefix_path}"
                        +zi-execute make PREFIX="$prefix_path" install
                    } || {
                        print "Error: make install failed" >&2
                        return 1
                    }
                else
                    { +zi-execute make PREFIX=$prefix_path install } || {
                        print "Error: make install failed" >&2
                        return 1
                    }
                fi
            else
                { 
                    print -- "== No install target, just build"
                    +zi-execute make PREFIX="${prefix_path}" 
                } || {
                    print "Error: make build failed" >&2
                    return 1
                }
                print -- "Warning: No install target found in $makefile_name. Built binaries are in: $clone_dir/$repo_name" >&2
                # cleanup_needed=0
            fi
            ;;
    esac
    print -- "Successfully completed!"
    return 0
}
# ]]]

# vim: ft=zsh sw=4 ts=4 et foldmarker=[[[,]]] foldmethod=marke
