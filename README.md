# Renamed master to main

As part of our inclusive naming effort the `master` branch was renamed to
`main`. Please updated your local configuration:

```
git branch --move master main
git branch --set-upstream-to=origin/main main
git remote set-head origin --auto
```
