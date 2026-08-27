#
# git_clone_or_update: clone a repo, or update it if it exists locally
#
# Given $1 a Git repostory, this with either clone
# or update depending if it exists or not locally.
#
git_clone_or_update() {
  _shlib_giturl=$1
  _shlib_gitrepo=${_shlib_giturl##*/}   # foo.git
  _shlib_gitrepo=${_shlib_gitrepo%.git} # foo
  if [ ! -d "$_shlib_gitrepo" ]; then
    git clone "$_shlib_giturl"
  else
    (cd "$_shlib_gitrepo" && git pull >/dev/null)
  fi
}
