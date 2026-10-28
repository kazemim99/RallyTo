/**
 * The response envelope. Rallyto's API forks AsanRezerve's middleware, so the shape is identical
 * (Booking: `AsanRezerve.API/Middleware/ApiResponseMiddleware.cs` for 2xx, `ExceptionHandlingMiddleware.cs` for
 * errors). Null members are omitted on success, and a blank 2xx body carries no `data` at all; 204 is never wrapped.
 */
export interface ResponseMetadata {
  requestId?: string
  traceId?: string
  timestamp?: string
  duration?: number
  path?: string
  method?: string
  version?: string
}

export interface ApiErrorDetail {
  code?: string | null
  message?: string | null
  errors?: Record<string, string[]> | null
}

export interface ApiEnvelope<T = unknown> {
  success: boolean
  /** A number on success; the error middleware serialises it as a string ("400"). */
  statusCode: number | string
  message?: string | null
  data?: T | null
  error?: ApiErrorDetail | null
  errors?: Record<string, string[]> | null
  metadata?: ResponseMetadata | null
}

export function isApiEnvelope(body: unknown): body is ApiEnvelope {
  return (
    typeof body === 'object' &&
    body !== null &&
    typeof (body as { success?: unknown }).success === 'boolean' &&
    'statusCode' in body
  )
}
