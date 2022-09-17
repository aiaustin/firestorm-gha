#!/bin/bash
# github actions helper to initialize environment variables for building firestorm
# -- humbletim 2022.03.27

set -eu

# function wrapper to avoid leaking variables when "sourced" into other scripts
function _fsenv() {
  local os
  if [[ ${RUNNER_OS+x} ]] ; then
    case $RUNNER_OS in
	Windows) os=windows ;;
        Linux) os=linux ;;
    esac
  fi
  if [[ ! ${os+x} ]] ; then
    case `uname -s` in
      MINGW*) os=windows ;;
      *) os=linux ;;
    esac
  fi

  # setenv <name> [default-value]
  #   exports the named variable and emits a key="value" to stdout
  #   (a no-op when both the variable doesn't exist and no default is specified)
  function setenv() {
    if [[ ! ${!1+x} ]] ; then
      if [[ $# -lt 2 ]] ; then
        echo "# setenv($1) -- no-op" >&2
        return 0
      fi
      # var not present assign to default and export 
      echo "# setenv($1,$2)" >&2
      printf -v "${1}" "%s" "${2}"
    fi
    echo "# export($1)" >&2
    [[ ${os} == linux ]] && eval "export ${1}"
    emitvar "$@"
  }

  function emitvar() {
    if [[ ${GITHUB_ACTIONS+x} ]] ; then
      # output github action (GITHUB_ENV) compatible multiline/escaped variables
      if [[ ${!1} == *$'\n'* ]] ; then
        echo "${1}<<EOF"
        echo "${!1}"
        echo "EOF"
      else
        echo "${1}=${!1}"
      fi
    else
      # output bash compatible multiline/escaped variables
      declare -p "${1}"
    fi
  }

  setenv GHA_TEST_WITH_SPACES "testing \"1\" 2 3...tab\t."

  if [[ ! ${GITHUB_WORKSPACE+x} ]] ; then
    case `uname -s` in
      MINGW*) local GITHUB_WORKSPACE=$(pwd -W) ;;
      *) local GITHUB_WORKSPACE=$PWD ;;
    esac
  fi
  echo "os=$os"

  setenv _3P_UTILSDIR ${GITHUB_WORKSPACE}/.github/3p

  ############################################################################
  # workaround for github actions receiving 403: Forbidden errors when trying to
  # download prebuilts from 3p.firestormviewer.org

  # 3p-<package_name> deps are resolved relative to this URL
  setenv INLINE_FS3P_GITURL https://github.com
  ### :/ also 403's with vcs.firestormviewer.org...
  ### setenv INLINE_FS3P_GITURL https://vcs.firestormviewer.org/3p-libraries

  # format: packagerepo@gitcommit[#alias]
  local growl=
  if [[ $os == 'windows' ]] ; then
    growl="holostorm/3p-gntp-growl@7ed68be"
  fi
  setenv INLINE_FS3P_DEPS "
    holostorm/3p-discord-rpc@a21e3dc#3p-discord-rpc
    holostorm/3p-ndPhysicsStub@aad4d9e
    holostorm/3p-freetype@577c3bdc
    holostorm/3p-openjpeg2@d23ab9af
    $growl
    holostorm/3p-glod@eecf86f
    ValveSoftware/openvr@d9cffe2#3p-openvr
  "

  # TODO: figure out where firestorm source code for 3p-dictionaries lives...
  #       but for now substituting the "official" LL prebuilt seems to work.

  # format: url=md5
  setenv ALTERNATE_FS3P_DEPS "
    http://automated-builds-secondlife-com.s3.amazonaws.com/ct2/55025/511964/dictionaries-1.538984-common-538984.tar.bz2=d778c6a3475bc35ee8b9615dfc38b4a9
  "
  # unused
  # http://automated-builds-secondlife-com.s3.amazonaws.com/ct2/55025/511964/dictionaries-1.538984-common-538984.tar.bz2=d778c6a3475bc35ee8b9615dfc38b4a9
  # https://automated-builds-secondlife-com.s3.amazonaws.com/ct2/78593/744010/freetype-2.4.4.557047-windows64-557047.tar.bz2=69307aaba16ac71531c9c4d930ace993
  # http://automated-builds-secondlife-com.s3.amazonaws.com/ct2/55004/511885/glod-1.0pre3.538980-windows64-538980.tar.bz2=6302ee1903ab419e76565d9eb6acd274
  # http://automated-builds-secondlife-com.s3.amazonaws.com/ct2/54974/511767/openjpeg-1.5.1.538970-windows64-538970.tar.bz2=5b5c80807fa8161f3480be3d89fe9516
  # https://bitbucket.org/kokua/3p-ndPhysicsStub/downloads/ndPhysicsStub-1.0-windows64-203290044.tar.bz2=bd172f8cf47ce5ba53a4d4128b2580d5
  ############################################################################

  ### AUTOBUILD_ environment variables

  setenv AUTOBUILD_VARIABLES_FILE ${GITHUB_WORKSPACE}/fs-build-variables/variables
  setenv AUTOBUILD_CONFIG_FILE ${GITHUB_WORKSPACE}/autobuild.xml
  setenv AUTOBUILD_INSTALLABLE_CACHE ${GITHUB_WORKSPACE}/autobuild-cache

  setenv AUTOBUILD_LOGLEVEL --verbose
  setenv AUTOBUILD_PLATFORM ${os}64
  setenv AUTOBUILD_ADDRSIZE 64
  setenv AUTOBUILD_VSVER 164
  setenv AUTOBUILD_CONFIGURATION ReleaseFS_open
  setenv AUTOBUILD_BUILD_ID 0

  ### environment variables specific to github actions / windows builds
  # setenv VIEWER_CHANNEL=FirestormVR-GHA
  setenv PYTHONUTF8 1
  setenv PreferredToolArchitecture x64
  setenv VIEWER_VERSION_REVISION dev
  if [[ $os == windows ]] ; then
    setenv FSBUILD_DIR build-vc${AUTOBUILD_VSVER}-${AUTOBUILD_ADDRSIZE}
  else
    setenv FSBUILD_DIR build-linux-x86_64
  fi
  setenv FSVS_TARGET Ninja # 'Visual Studio 16 2019'

  setenv VIEWER_VERSION_STR `echo $(cat indra/newview/VIEWER_VERSION.txt)`.${AUTOBUILD_BUILD_ID}
  setenv VIEWER_VERSION_GITHASH $(git log -n 1 | grep "Merge " | awk '{ print $2 }' | xargs git rev-parse --short 2>/dev/null || git rev-parse --short HEAD)
  setenv VIEWER_CHANNEL
  unset _fsenv
}

if [[ ! ${GITHUB_ACTIONS+x} ]] ; then
  if (return 0 2>/dev/null) ; then
    # fsenv.sh was sourced ; export only
    _fsenv > /dev/null
  fi
elif [[ -n $# ]] ; then
  # fsenv.sh was passed subcommands ; export and execute
  _fsenv > /dev/null
  "$@"
else
  # fsenv.sh was called without arguments ; export and echo to stdout
  _fsenv
fi
