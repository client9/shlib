#
# git_clone_or_update: clone a repo, or update it if it exists locally
#
# Given $1 a Git repostory, this with either clone
# or update depending if it exists or not locally.
#
git_clone_or_update() {
  giturl=$1
  gitrepo=${giturl##*/}   # foo.git
  gitrepo=${gitrepo%.git} # foo
  if [ ! -d "$gitrepo" ]; then
    git clone "$giturl"
  else
    (cd "$gitrepo" && git pull >/dev/null)
  fi
}
