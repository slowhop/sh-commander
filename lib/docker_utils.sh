get_container_id() {
    local container_pattern="$1"
    CONTAINER_ID=$(docker ps --filter "name=${container_pattern}" --format "{{.ID}}")

    if [ -z "$CONTAINER_ID" ]; then
        return 1
    fi

    echo "$CONTAINER_ID"
    return 0
}

get_legacy_container_id() {
    get_container_id "sh[-_]legacy[-_]legacy"
}

get_redis_container_id() {
    get_container_id "sh[-_]legacy[-_]redis[-_]1"
}

get_indexer_container_id() {
    get_container_id "sh[-_]legacy[-_]indexer"
}
