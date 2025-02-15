get_container_id() {
    CONTAINER_ID=$(docker ps --filter "name=sh-legacy-legacy" --format "{{.ID}}")
    if [ -z "$CONTAINER_ID" ]; then
        return 1
    fi
    echo "$CONTAINER_ID"
    return 0
}
