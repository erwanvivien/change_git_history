#!/bin/bash

edit_file=$(mktemp change_date_XXXXXX --tmpdir=/tmp)
save_file=$(mktemp change_date_XXXXXX --tmpdir=/tmp)
trap "rm -f $edit_file" EXIT
trap "rm -f $save_file" EXIT

git log --pretty=format:"%cI | %H | %s" > "$save_file"
echo "" >> "$save_file" # adds last newline"
cp "$save_file" "$edit_file"

EDITOR=$(git var GIT_EDITOR)

# Let user edit file
"$EDITOR" "$edit_file"

edited_lines=$(diff --changed-group-format="%>" --unchanged-group-format="" "$save_file" "$edit_file")

#             year  - month  -  day   T  hour  :  min   :  sec   +   00   :   00
date_regex='[0-9]+-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}\+[0-9]{2}:[0-9]{2}'
hash_regex='[0-9a-f]{40}'
msg_regex='.*'
commit_regex="^${date_regex} \\| ${hash_regex} \\| ${msg_regex}$"

UPDATES=""
MESSAGES="
if [ \"a\" = \"b\" ];
then
    :
"
while IFS= read -r line; do
    [[ -z "$line" ]] && continue;
    [[ "$line" =~ $commit_regex ]] || continue

    pattern=' | '
    splitted="$(sed "s/$pattern/\n/g" <<< "$line")"

    read -d "\n" com_date com_hash com_msg <<< "$splitted"

    echo "date: $com_date"
    echo "hash: $com_hash"
    echo "msg : $com_msg"
    echo

    UPDATES="$UPDATES""
if [ \"\$GIT_COMMIT\" = \"$com_hash\" ];
then
    export GIT_AUTHOR_DATE=\"$com_date\";
    export GIT_COMMITTER_DATE=\"$com_date\";
fi;
"
    # escape single quotes: 'a'b' => 'a'"'"'b'
    #                         ^          ^
    com_msg_esc=${com_msg//\'/\'\"\'\"\'}
    MESSAGES="$MESSAGES""
elif [ \"\$GIT_COMMIT\" = '$com_hash' ];
then
    sed 's/.*/$com_msg_esc/g'"
done <<< "$edited_lines"

MESSAGES="$MESSAGES""
else
    cat -
fi;
"

git filter-branch -f \
    --env-filter "$UPDATES" \
    --msg-filter "$MESSAGES" \
    -- --all