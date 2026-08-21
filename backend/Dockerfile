FROM golang:1.26-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o /mwendo-backend ./cmd/api

FROM alpine:3.21
RUN addgroup -S mwendo && adduser -S mwendo -G mwendo
WORKDIR /
COPY --from=builder /mwendo-backend /mwendo-backend
USER mwendo
EXPOSE 8080
ENTRYPOINT ["/mwendo-backend"]
