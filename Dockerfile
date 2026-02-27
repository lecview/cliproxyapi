FROM golang:1.26-alpine AS builder

WORKDIR /app

COPY go.mod go.sum ./

RUN go mod download

COPY . .

ARG VERSION=dev
ARG COMMIT=none
ARG BUILD_DATE=unknown

RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w -X 'main.Version=${VERSION}' -X 'main.Commit=${COMMIT}' -X 'main.BuildDate=${BUILD_DATE}'" -o ./CLIProxyAPI ./cmd/server/

FROM alpine:3.22.0

RUN apk add --no-cache tzdata

RUN mkdir /CLIProxyAPI

COPY --from=builder ./app/CLIProxyAPI /CLIProxyAPI/CLIProxyAPI

COPY config.example.yaml /CLIProxyAPI/config.example.yaml

WORKDIR /CLIProxyAPI

EXPOSE 8317

ENV TZ=Asia/Shanghai

RUN cp /usr/share/zoneinfo/${TZ} /etc/localtime && echo "${TZ}" > /etc/timezone

# 启动脚本：如果持久化目录没有 config.yaml，就从默认模板复制一份过去
# 然后用软链接指向持久化目录的配置文件
CMD sh -c '\
  if [ ! -f /root/.cli-proxy-api/config.yaml ]; then \
    cp /CLIProxyAPI/config.example.yaml /root/.cli-proxy-api/config.yaml; \
    echo "已从模板创建默认配置文件"; \
  fi && \
  ln -sf /root/.cli-proxy-api/config.yaml /CLIProxyAPI/config.yaml && \
  echo "配置文件已链接到持久化目录" && \
  ./CLIProxyAPI'
