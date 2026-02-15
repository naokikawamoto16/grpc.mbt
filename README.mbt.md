# grpc.mbt

MoonBit bindings for gRPC (JavaScript target), built as a third-party library on @grpc/grpc-js.

> [!WARNING]
> This library is in early development. Only a subset of features is currently available.
> The API is unstable and may introduce breaking changes without notice.
> All `v0.x` releases are experimental and do not guarantee backward compatibility.
> It is not recommended for production use.

## Feature Coverage

### RPC Types

| RPC Type | Client-side | Server-side |
| --- | --- | --- |
| Unary | ✅ | 🚧 |
| Server Streaming | 🚧 | 🚧 |
| Client Streaming | 🚧 | 🚧 |
| Bidirectional Streaming | 🚧 | 🚧 |

### Core Features

- ✅ Channel management
- ✅ TLS/mTLS support
- ✅ Metadata (text and binary values)
- ✅ All 16 gRPC status codes
- ✅ Timeouts/deadlines
- ✅ Request cancellation
- ✅ Wait-for-ready
- ⏳ Interceptors (planned)
- ⏳ Compression (planned)
- ⏳ Retries (planned)

## License

[Apache-2.0](LICENSE)

## Notices

gRPC® is a registered trademark of The Linux Foundation. This project is not affiliated with, endorsed by, or sponsored by The Linux Foundation, the Cloud Native Computing Foundation (CNCF), or the gRPC project.

This library interfaces with [@grpc/grpc-js](https://github.com/grpc/grpc-node/tree/master/packages/grpc-js) (Apache-2.0), the official Node.js implementation of gRPC. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for complete third-party license information.

For JavaScript runtime execution, install Node.js dependency `@grpc/grpc-js` in the consuming environment.
