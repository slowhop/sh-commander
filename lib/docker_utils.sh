get_container_id() {
    CONTAINER_ID=$(docker ps --filter "name=sh-legacy-legacy" --format "{{.ID}}")
    if [ -z "$CONTAINER_ID" ]; then
        echo "${RED}Cannot find a running container for the legacy application.${NO_COLOR}"
        exit 1
    fi
    echo "$CONTAINER_ID"
}