# bash-scripts
Contains various bash-scripts

## Merge multiple mp3 files
To merge multiple mp3 into one single file, use the merge-mp3.sh script.
It uses ffmpeg to extract id3 tags and album cover and merges the multiple files into one.

usage:

```
brew install ffmpeg
./merge-mp3.sh "/path/to/folder"
```

to make the script available everywhere:

```
cp merge-mp3.sh ~/bin
nano ~/.zshrc
alias mmp3='merge-mp3.sh'
source ~/.zshrc
```

then you can use it like this:

```
mmp3 "/path/to/folder"
```

