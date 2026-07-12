#!/bin/bash

function update_nginx_weight() {
    # 입력값: $1 = blue 트래픽 비율, $2 = green 트래픽 비율 (예: update_nginx_weight 90 10)
    local BLUE=$1; local GREEN=$2
    # 비율이 0보다 큰 서버만 명단에 이어붙입니다(+=). weight=0은 문법 오류라 아예 제외!
    CONF="upstream backend {"
    [ "$BLUE" -gt 0 ]  && CONF+=" server app-blue:8080 weight=$BLUE;"
    [ "$GREEN" -gt 0 ] && CONF+=" server app-green:8081 weight=$GREEN;"
    CONF+=" }"
    # 완성된 설정을 Nginx 컨테이너 안에 덮어쓰고 프록시를 리로드 처리합니다.
    docker exec nginx-proxy sh -c "echo '$CONF' > /etc/nginx/conf.d/upstream.inc"
    docker exec nginx-proxy nginx -s reload
}

IS_BLUE=$(docker ps -q -f name="^app-blue$")

if [ -n "$IS_BLUE" ]; then
    CURRENT="blue";  TARGET="green"; TARGET_PORT=8081; TARGET_COLOR="🟢 GREEN"
else
    CURRENT="green"; TARGET="blue";  TARGET_PORT=8080; TARGET_COLOR="🔵 BLUE"
fi

docker build -t my-canary-app .


docker rm -f app-$TARGET 2>/dev/null


docker run -d --name app-$TARGET --network canary-net \
  -e PORT=$TARGET_PORT -e COLOR="$TARGET_COLOR" \
  my-canary-app

sleep 5
RESPONSE=$(docker exec nginx-proxy sh -c "wget -qO- http://app-$TARGET:${TARGET_PORT}")

if [ -z "$RESPONSE" ]; then
    echo "❌ 헬스체크 실패! 신규 서버 통신 접근 불가. 즉시 롤백 처리합니다."
    docker rm -f app-$TARGET
    exit 1
fi

if [ "$TARGET" == "green" ]; then update_nginx_weight 90 10; else update_nginx_weight 10 90; fi
sleep 15


update_nginx_weight 50 50
sleep 15


if [ "$TARGET" == "green" ]; then update_nginx_weight 0 100; else update_nginx_weight 100 0; fi


docker rm -f app-$CURRENT
