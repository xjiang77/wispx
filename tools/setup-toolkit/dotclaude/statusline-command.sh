#!/bin/bash
input=$(cat)
model_name=$(echo "$input" | jq -r '.model.display_name')
project_dir=$(echo "$input" | jq -r '.workspace.project_dir')
current_dir=$(echo "$input" | jq -r '.workspace.current_dir')

usage=$(echo "$input" | jq '.context_window.current_usage')
if [ "$usage" != "null" ]; then
    current=$(echo "$usage" | jq '.input_tokens + .cache_creation_input_tokens + .cache_read_input_tokens')
    size=$(echo "$input" | jq '.context_window.context_window_size')
    pct=$((current * 100 / size))
    context_info="${pct}%"
else
    context_info="0%"
fi

if git -C "$current_dir" rev-parse --git-dir > /dev/null 2>&1; then
    branch=$(git -C "$current_dir" --no-optional-locks branch --show-current 2>/dev/null)
    if git -C "$current_dir" --no-optional-locks diff-index --quiet HEAD -- 2>/dev/null; then
        git_status="✓"
    else
        git_status="✗"
    fi
    git_info=" (${branch} ${git_status})"
else
    git_info=""
fi

if [ "$current_dir" = "$project_dir" ]; then
    path_info="$(basename "$project_dir")"
else
    rel_path="${current_dir#$project_dir/}"
    path_info="$(basename "$project_dir")/$rel_path"
fi

printf "\033[2m%s | %s | %s%s\033[0m" "$model_name" "$context_info" "$path_info" "$git_info"
