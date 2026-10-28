import { AxiosError, AxiosHeaders, type AxiosAdapter, type AxiosResponse, type InternalAxiosRequestConfig } from 'axios'
import apiClient from '../axios'
import type { AuthTokens } from '../../types/auth.types'

/** One request as the server saw it. */
export interface RecordedRequest {
  method: string
  url: string
  body: unknown
  authorization: string | null
  /** The query parameters, as passed to axios; undefined when the request had none. */
  params?: Record<string, unknown>
}

export type FakeReply = { status: number; body?: unknown } | { network: true }

export type Handler = (request: RecordedRequest, config: InternalAxiosRequestConfig) => FakeReply | Promise<FakeReply>

/** A success envelope, as ApiResponseMiddleware writes it. */
export const envelope = <T>(data: T, statusCode = 200) => ({
  success: true,
  statusCode,
  message: 'Request completed successfully',
  data,
  metadata: { requestId: 'test', traceId: 'trace', timestamp: '2026-10-23T10:00:00Z' },
})

/** An error envelope, as ExceptionHandlingMiddleware writes it: the status code is a string there. */
export const errorEnvelope = (statusCode: number, message: string, code = 'ERROR', errors?: Record<string, string[]>) => ({
  success: false,
  statusCode: String(statusCode),
  message,
  data: null,
  error: { code, message, errors },
  metadata: { requestId: 'test', traceId: 'trace', timestamp: '2026-10-23T10:00:00Z' },
})

export const tokens = (roles: string[], suffix = '1'): AuthTokens => ({
  accessToken: `access-${suffix}`,
  accessTokenExpiresAt: '2026-10-23T11:00:00Z',
  refreshToken: `refresh-${suffix}`,
  refreshTokenExpiresAt: '2026-11-22T10:00:00Z',
  profileCompleted: true,
  roles,
})

/** A promise resolved from outside, to hold a reply until the test lets it go. */
export function deferred<T = void>() {
  let resolve!: (value: T) => void
  const promise = new Promise<T>((r) => (resolve = r))
  return { promise, resolve }
}

/**
 * Replaces the API client's transport with `handler`, so a test plays the server: no sockets, no extra library.
 * Requests are recorded in arrival order.
 */
export function installFakeApi(handler: Handler) {
  const requests: RecordedRequest[] = []
  const original = apiClient.defaults.adapter

  const adapter: AxiosAdapter = async (config) => {
    const header = config.headers?.get?.('Authorization')
    const request: RecordedRequest = {
      method: (config.method ?? 'get').toUpperCase(),
      url: config.url ?? '',
      body: typeof config.data === 'string' && config.data ? JSON.parse(config.data) : config.data,
      authorization: typeof header === 'string' ? header : null,
      ...(config.params ? { params: { ...config.params } } : {}),
    }
    requests.push(request)

    const reply = await handler(request, config)
    if ('network' in reply) throw new AxiosError('Network Error', AxiosError.ERR_NETWORK, config, {})

    const response: AxiosResponse = {
      data: reply.body ?? '',
      status: reply.status,
      statusText: String(reply.status),
      headers: new AxiosHeaders(),
      config,
      request: {},
    }
    if (reply.status >= 200 && reply.status < 300) return response
    throw new AxiosError(
      `Request failed with status code ${reply.status}`,
      reply.status >= 500 ? AxiosError.ERR_BAD_RESPONSE : AxiosError.ERR_BAD_REQUEST,
      config,
      {},
      response,
    )
  }

  apiClient.defaults.adapter = adapter
  return {
    requests,
    to: (url: string) => requests.filter((r) => r.url === url),
    restore: () => {
      apiClient.defaults.adapter = original
    },
  }
}
