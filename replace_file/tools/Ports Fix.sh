#!/bin/bash
# 每次运行切换 dArkOS4Clone ↔ ArkOS4Clone，保留括号内容和空格

PLYMOUTH_FILE="/usr/share/plymouth/themes/text.plymouth"

# 读取当前标题（去掉 title=）
CURRENT_TITLE=$(grep "^title=" "$PLYMOUTH_FILE" | cut -d= -f2-)

# 提取括号及前面的空格内容
BRACKET_CONTENT=$(echo "$CURRENT_TITLE" | sed -n 's/^[^ ]*\(.*\)/\1/p')

# 切换主标题
if [[ "$CURRENT_TITLE" == dArkOS4Clone* ]]; then
    NEW_TITLE="ArkOS4Clone$BRACKET_CONTENT"
else
    NEW_TITLE="dArkOS4Clone$BRACKET_CONTENT"
fi

# 替换文件中的 title 行
sudo sed -i "/^title=/c\title=$NEW_TITLE" "$PLYMOUTH_FILE"

echo "标题已切换为: $NEW_TITLE"