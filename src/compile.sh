#!/bin/bash

# 获取脚本运行目录
DIR=$(dirname $(readlink -f "$0/../"))
POSTS_DIR=$(dirname $(readlink -f "$DIR"))/posts/
echo $POSTS_DIR

git -C "$DIR" pull origin master
# 拉取博文
git -C "$POSTS_DIR" pull origin master
# 生成博文
node "$DIR/src/compile.js" "$POSTS_DIR" "$DIR"
# 推送更新
git -C "$DIR" add *
git -C "$DIR" add .posts/
git -C "$DIR" add 3rd-lib/
git -C "$DIR" add page/
git -C "$DIR" add resource/
git -C "$DIR" add src/
git -C "$DIR" commit -m "from compile.sh"
git -C "$DIR" push